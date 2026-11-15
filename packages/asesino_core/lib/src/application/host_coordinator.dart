import 'dart:async';
import 'dart:math';

import '../domain/actions.dart';
import '../domain/config.dart';
import '../domain/enums.dart';
import '../domain/game_state.dart';
import '../domain/narration.dart';
import '../domain/night_resolver.dart';
import '../domain/role_assigner.dart';
import '../domain/victory.dart';
import '../domain/vote_resolver.dart';
import 'backend.dart';
import 'docs.dart';

class GameStartException implements Exception {
  GameStartException(this.errors);
  final List<String> errors;
  @override
  String toString() => errors.join(' ');
}

/// Duraciones de las fases que no son configurables por el usuario.
class HostTimings {
  const HostTimings({
    this.roleReveal = const Duration(seconds: 15),
    this.dawn = const Duration(seconds: 10),
    this.voteResult = const Duration(seconds: 10),
    this.decoyStep = const Duration(seconds: 8),
    this.heartbeat = const Duration(seconds: 60),
    this.presenceEvery = const Duration(seconds: 30),
    this.offlineAfter = const Duration(seconds: 130),
  });
  final Duration roleReveal;
  final Duration dawn;
  final Duration voteResult;

  /// Duración de un paso nocturno sin jugadores vivos con ese rol (señuelo,
  /// para no delatar quién ha muerto).
  final Duration decoyStep;
  final Duration heartbeat;
  final Duration presenceEvery;
  final Duration offlineAfter;
}

/// Foto del estado del anfitrión para la interfaz (incluye secretos: sólo
/// se muestra en el panel de narrador / moderación).
class HostSnapshot {
  const HostSnapshot({
    required this.room,
    required this.members,
    required this.state,
    required this.actedUids,
    required this.votedUids,
    required this.deadline,
    required this.lost,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final GameState? state;
  final Set<String> actedUids;
  final Set<String> votedUids;
  final DateTime? deadline;
  final bool lost;
}

/// Cerebro de la partida en el dispositivo del anfitrión.
///
/// * Valida las acciones y los votos que llegan por Firestore.
/// * Ejecuta el motor de reglas (`NightResolver`, `VoteResolver`, ...).
/// * Publica cada transición con una única escritura atómica ([Commit]).
/// * Es testeable sin Flutter ni Firebase: el tiempo se avanza con [tick].
///
/// Modelo de confianza: el anfitrión es un moderador, no un servidor seguro.
/// Ve todos los roles y un cliente modificado podría hacer trampa.
class HostCoordinator {
  HostCoordinator({
    required this.backend,
    required this.roomId,
    required RoomDoc room,
    Random? rng,
    DateTime Function()? now,
    this.timings = const HostTimings(),
  })  : _room = room,
        _rng = rng ?? Random.secure(),
        _now = now ?? DateTime.now;

  final GameBackend backend;
  final String roomId;
  final HostTimings timings;
  final Random _rng;
  final DateTime Function() _now;

  RoomDoc _room;
  List<MemberDoc> _members = const [];
  GameState? _state;
  int _version = 0;
  Map<String, NightAction> _actions = {};
  Set<String> _actionIds = {};
  Map<String, String> _votes = {};
  Set<String> _voteIds = {};
  DateTime? _deadline;
  bool _lost = false;
  bool _stopped = false;
  DateTime? _lastBeat;
  DateTime? _lastPresence;
  final Map<String, ({int value, DateTime changed})> _presenceSeen = {};
  Map<String, int> _presence = {};

  StreamSubscription<List<MemberDoc>>? _membersSub;
  StreamSubscription<RoomDoc?>? _roomSub;
  StreamSubscription<Map<String, int>>? _presenceSub;
  StreamSubscription<List<ActionDoc>>? _actionsSub;
  StreamSubscription<List<VoteDoc>>? _votesSub;
  final StreamController<HostSnapshot> _snapshots = StreamController.broadcast();
  Future<void> _tail = Future.value();

  /// Acciones/votos descartados por el anfitrión (depuración y pruebas).
  final List<String> rejectedLog = [];

  /// Se invoca si otro dispositivo toma el rol de anfitrión.
  void Function()? onLost;

  RoomDoc get room => _room;
  GameState? get state => _state;
  DateTime? get deadline => _deadline;
  bool get lost => _lost;
  Stream<HostSnapshot> get snapshots => _snapshots.stream;
  bool get _auto => _room.narrator == NarratorMode.auto;

  HostSnapshot get snapshot => HostSnapshot(
        room: _room,
        members: _members,
        state: _state,
        actedUids: _actions.keys.toSet(),
        votedUids: _votes.keys.toSet(),
        deadline: _deadline,
        lost: _lost,
      );

  // ---------------------------------------------------------------- ciclo

  /// Empieza a escuchar. Si la sala ya estaba en partida (recuperación tras
  /// reconexión o cambio de anfitrión), restaura el estado desde `hostState`.
  Future<void> start() async {
    await _enqueue(() async {
      final current = await backend.getRoom(roomId);
      if (current != null) _room = current;
      _version = _room.version;

      if (_room.phase != Phase.lobby) {
        final hs = await backend.readHostState(roomId);
        if (hs == null) {
          throw StateError('No hay estado guardado para recuperar la partida.');
        }
        _state = hs.state;
        if (_room.phase == Phase.finished) {
          _deadline = null;
        }
      }

      _membersSub = backend.watchMembers(roomId).listen((m) {
        _members = m;
        _notify();
        _enqueue(_handleAbandons).catchError(_swallow);
        _enqueue(_earlyCheck).catchError(_swallow);
      });
      _roomSub = backend.watchRoom(roomId).listen((r) {
        if (r != null && r.hostUid != backend.uid) _markLost();
      });
      _presenceSub = backend.watchPresence(roomId).listen((p) => _presence = p);

      await backend.heartbeat(roomId, asHost: true);
      _lastBeat = _now();

      if (_state != null && _room.phase != Phase.finished) {
        // Recuperación: si el narrador era humano y este dispositivo es un
        // jugador, pasa a automático; reinicia el temporizador de la fase.
        if (_room.narrator == NarratorMode.human &&
            _members.any((m) => m.uid == backend.uid && !m.isNarrator)) {
          await _commitRoom(_room.copyWith(narrator: NarratorMode.auto));
        }
        _subscribeForPhase();
        _arm(Duration(milliseconds: _room.phaseDurationMs));
      }
      _notify();
    });
  }

  Future<void> stop() async {
    _stopped = true;
    await _membersSub?.cancel();
    await _roomSub?.cancel();
    await _presenceSub?.cancel();
    await _actionsSub?.cancel();
    await _votesSub?.cancel();
    await _snapshots.close();
  }

  /// Llamar periódicamente (p. ej. cada segundo). Gestiona temporizadores,
  /// latido de presencia y avance automático.
  Future<void> tick() => _enqueue(() async {
        if (_lost || _stopped) return;
        final t = _now();
        if (_lastBeat == null || t.difference(_lastBeat!) >= timings.heartbeat) {
          await backend.heartbeat(roomId, asHost: true);
          _lastBeat = t;
        }
        await _presenceTick(t);
        if (_auto && _deadline != null && !t.isBefore(_deadline!)) {
          await _advance();
        } else {
          await _earlyCheck();
        }
      });

  /// Avanza a la siguiente fase/paso (narrador humano o botón "saltar").
  Future<void> advance() => _enqueue(_advance);

  // -------------------------------------------------------------- lobby

  Future<void> updateLobby({
    String? name,
    GameConfig? config,
    NarratorMode? narrator,
    bool? hostPlays,
  }) =>
      _enqueue(() async {
        _requirePhase(Phase.lobby);
        final mode = narrator ?? _room.narrator;
        final cfg = (config ?? _room.config).copyWith(narrator: mode);
        final patches = <String, Map<String, dynamic>>{};
        final plays = hostPlays ?? (mode == NarratorMode.auto ? true : _hostPlays());
        patches[backend.uid] = {'isNarrator': !plays};
        await _commit(
          room: _room.copyWith(
            name: name ?? _room.name,
            config: cfg,
            narrator: mode,
          ),
          memberPatches: patches,
        );
      });

  Future<void> kick(String uid) => _enqueue(() async {
        _requirePhase(Phase.lobby);
        if (uid == backend.uid) return;
        await _commit(room: _room, deleteMembers: [uid]);
      });

  bool _hostPlays() {
    final me = _members.where((m) => m.uid == backend.uid);
    return me.isEmpty ? true : !me.first.isNarrator;
  }

  List<MemberDoc> get _participants => [
        for (final m in _members)
          if (!m.isNarrator && !m.left) m
      ]..sort((a, b) {
          final c = a.joinedAtMs.compareTo(b.joinedAtMs);
          return c != 0 ? c : a.uid.compareTo(b.uid);
        });

  /// Errores que impiden empezar (vacío = se puede empezar).
  List<String> startErrors() => _room.config.validate(_participants.length);

  Future<void> startGame({Map<String, RoleId> forcedRoles = const {}}) => _enqueue(() async {
        _requirePhase(Phase.lobby);
        final players = _participants;
        final errors = _room.config.validate(players.length);
        if (errors.isNotEmpty) throw GameStartException(errors);

        final roles = RoleAssigner.assign(
          [for (final p in players) p.uid],
          _room.config,
          _rng,
          forced: forcedRoles,
        );
        final state = GameState(
          config: _room.config,
          phase: Phase.roleReveal,
          round: 1,
          players: [
            for (final p in players)
              PlayerState(uid: p.uid, name: p.name, role: roles[p.uid]!)
          ],
        );
        await _commit(
          state: state,
          room: _room.copyWith(
            phase: Phase.roleReveal,
            round: 1,
            clearNightStep: true,
            nightStepIdx: 0,
            voteSeq: 0,
            voteCandidates: const [],
            clearDawn: true,
            clearVoteResult: true,
            clearWinner: true,
            finalRoles: const {},
            narration: Narrator.roleReveal(),
            phaseDurationMs: timings.roleReveal.inMilliseconds,
          ),
          privates: {for (final p in players) p.uid: PrivateDoc.forPlayer(state, p.uid)},
          memberPatches: {
            for (final p in players) p.uid: {'alive': true, 'revealedRole': null}
          },
        );
        _arm(timings.roleReveal);
      });

  /// Vuelve al lobby tras una partida terminada (revancha).
  Future<void> rematch() => _enqueue(() async {
        _requirePhase(Phase.finished);
        await _commit(
          room: _room.copyWith(
            phase: Phase.lobby,
            round: 0,
            clearNightStep: true,
            nightStepIdx: 0,
            voteSeq: 0,
            voteCandidates: const [],
            clearDawn: true,
            clearVoteResult: true,
            clearWinner: true,
            finalRoles: const {},
            narration: const NarrationLine(''),
            phaseDurationMs: 0,
          ),
          memberPatches: {
            for (final m in _members)
              if (!m.left) m.uid: {'alive': true, 'revealedRole': null}
          },
          deleteMembers: [for (final m in _members) if (m.left) m.uid],
        );
        _state = null;
        _deadline = null;
      });

  // ---------------------------------------------------------- transiciones

  Future<void> _advance() async {
    final s = _state;
    if (_lost || _stopped || s == null) return;
    switch (_room.phase) {
      case Phase.roleReveal:
        await _enterNight(1);
      case Phase.night:
        final steps = s.config.nightSteps(s.round);
        if (_room.nightStepIdx + 1 < steps.length) {
          await _enterStep(_room.nightStepIdx + 1);
        } else {
          await _resolveNight();
        }
      case Phase.dawn:
        await _afterDawn();
      case Phase.discussion:
        await _enterVoting();
      case Phase.voting:
        await _resolveVoting();
      case Phase.voteResult:
        await _afterVoteResult();
      case Phase.lobby:
      case Phase.victoryCheck:
      case Phase.nextRound:
      case Phase.finished:
        break;
    }
  }

  Duration _stepDuration(GameState s, RoleId role) {
    final hasActors = s.alivePlayersWithRole(role).isNotEmpty;
    final real = Duration(seconds: s.config.nightStepSeconds);
    if (hasActors) return real;
    return timings.decoyStep < real ? timings.decoyStep : real;
  }

  Future<void> _enterNight(int round) async {
    var s = _state!.copyWith(phase: Phase.night, round: round);
    final steps = s.config.nightSteps(round);
    final first = steps.first;
    final d = _stepDuration(s, first);
    _actions = {};
    _actionIds = {};
    _subscribeActions(round);
    final intro = Narrator.nightStart(round);
    final wake = Narrator.wake(first);
    await _commit(
      state: s,
      room: _room.copyWith(
        phase: Phase.night,
        round: round,
        nightStep: first,
        nightStepIdx: 0,
        phaseDurationMs: d.inMilliseconds,
        clearDawn: true,
        clearVoteResult: true,
        voteCandidates: const [],
        narration: NarrationLine('${intro.text} ${wake.text}', Cue.nightStart),
      ),
    );
    _arm(d);
  }

  Future<void> _enterStep(int idx) async {
    final s = _state!;
    final steps = s.config.nightSteps(s.round);
    final prev = steps[idx - 1];
    final next = steps[idx];
    final d = _stepDuration(s, next);
    await _commit(
      state: s,
      room: _room.copyWith(
        nightStep: next,
        nightStepIdx: idx,
        phaseDurationMs: d.inMilliseconds,
        narration: NarrationLine(
          '${Narrator.sleep(prev).text} ${Narrator.wake(next).text}',
          Cue.wake,
        ),
      ),
    );
    _arm(d);
  }

  Map<String, Map<String, dynamic>> _deathPatches(List<Death> deaths, GameState s) => {
        for (final d in deaths)
          d.uid: {
            'alive': false,
            if (s.config.revealRoleOnDeath) 'revealedRole': s.player(d.uid)!.role.name,
          }
      };

  Future<void> _resolveNight() async {
    final s = _state!;
    final outcome = NightResolver.resolve(s, _actions.values.toList(), _rng);
    rejectedLog.addAll(outcome.rejected);
    final ns = outcome.state.copyWith(phase: Phase.dawn);

    final refresh = <String>{
      for (final i in outcome.investigations) i.police,
      ...outcome.newLastProtected.keys,
      if (outcome.newLovers.isNotEmpty) ...outcome.newLovers,
      if (outcome.newLovers.isNotEmpty && ns.cupidUid != null) ns.cupidUid!,
    };
    final deadNames = [for (final d in outcome.deaths) ns.player(d.uid)!.name];
    final saved = s.config.announceSaves && outcome.saved != null;
    final report = DawnReport(deaths: outcome.deaths, saved: saved);

    await _actionsSub?.cancel();
    _actionsSub = null;
    final toDelete = _actionIds.toList();
    await _commit(
      state: ns,
      room: _room.copyWith(
        phase: Phase.dawn,
        clearNightStep: true,
        nightStepIdx: 0,
        dawn: report,
        phaseDurationMs: timings.dawn.inMilliseconds,
        narration: Narrator.dawn(deadNames, saved: saved),
      ),
      privates: {for (final u in refresh) u: PrivateDoc.forPlayer(ns, u)},
      memberPatches: _deathPatches(outcome.deaths, ns),
      deleteActions: toDelete,
    );
    _actions = {};
    _actionIds = {};
    _arm(timings.dawn);
  }

  Future<void> _afterDawn() async {
    final s = _state!;
    final w = VictoryChecker.check(s);
    if (w != null) {
      await _finish(w);
    } else {
      await _enterDiscussion();
    }
  }

  Future<void> _enterDiscussion() async {
    final s = _state!.copyWith(phase: Phase.discussion);
    final secs = s.config.discussionSeconds;
    await _commit(
      state: s,
      room: _room.copyWith(
        phase: Phase.discussion,
        phaseDurationMs: secs * 1000,
        narration: Narrator.discussion(secs),
      ),
    );
    _arm(Duration(seconds: secs));
  }

  Future<void> _enterVoting({List<String> candidates = const []}) async {
    final s = _state!.copyWith(phase: Phase.voting);
    final seq = _room.voteSeq + 1;
    _votes = {};
    _voteIds = {};
    _subscribeVotes(seq);
    final secs = s.config.votingSeconds;
    await _commit(
      state: s,
      room: _room.copyWith(
        phase: Phase.voting,
        voteSeq: seq,
        voteCandidates: candidates,
        clearVoteResult: true,
        phaseDurationMs: secs * 1000,
        narration: candidates.isEmpty
            ? Narrator.voting()
            : Narrator.voteResult(eliminatedName: null, tie: true, revote: true),
      ),
    );
    _arm(Duration(seconds: secs));
  }

  Future<void> _resolveVoting() async {
    final s = _state!;
    final isRevote = _room.voteCandidates.isNotEmpty;
    final o = VoteResolver.resolve(
      s,
      _votes,
      _rng,
      candidates: isRevote ? _room.voteCandidates : null,
      isRevote: isRevote,
    );
    final ns = o.state.copyWith(phase: Phase.voteResult);
    final result = VoteResultDoc(
      tally: o.tally,
      abstentions: o.abstentions,
      eliminated: o.eliminated,
      tied: o.tied,
      revote: o.needsRevote,
      votes: s.config.secretVotes ? const {} : o.validVotes,
    );
    await _votesSub?.cancel();
    _votesSub = null;
    final toDelete = _voteIds.toList();
    await _commit(
      state: ns,
      room: _room.copyWith(
        phase: Phase.voteResult,
        voteResult: result,
        phaseDurationMs: timings.voteResult.inMilliseconds,
        narration: Narrator.voteResult(
          eliminatedName: o.eliminated == null ? null : ns.player(o.eliminated!)!.name,
          tie: o.tied.length > 1,
          revote: o.needsRevote,
        ),
      ),
      memberPatches: _deathPatches(o.deaths, ns),
      deleteVotes: toDelete,
    );
    _votes = {};
    _voteIds = {};
    _arm(timings.voteResult);
  }

  Future<void> _afterVoteResult() async {
    final s = _state!;
    final vr = _room.voteResult;
    if (vr != null && vr.revote) {
      await _enterVoting(candidates: vr.tied);
      return;
    }
    final w = VictoryChecker.check(s);
    if (w != null) {
      await _finish(w);
    } else {
      await _enterNight(s.round + 1);
    }
  }

  Future<void> _finish(Winner w) async {
    final s = _state!.copyWith(phase: Phase.finished, winner: w);
    await _actionsSub?.cancel();
    await _votesSub?.cancel();
    _actionsSub = null;
    _votesSub = null;
    await _commit(
      state: s,
      room: _room.copyWith(
        phase: Phase.finished,
        winner: w,
        clearNightStep: true,
        phaseDurationMs: 0,
        finalRoles: {for (final p in s.players) p.uid: p.role},
        narration: Narrator.victory(w),
      ),
      memberPatches: {
        for (final p in s.players) p.uid: {'revealedRole': p.role.name}
      },
      deleteActions: _actionIds.toList(),
      deleteVotes: _voteIds.toList(),
    );
    _deadline = null;
  }

  /// Abandono: se marca `left` en el miembro; el anfitrión elimina al jugador.
  Future<void> _handleAbandons() async {
    final s = _state;
    if (_lost || _stopped || s == null) return;
    if (_room.phase == Phase.lobby || _room.phase == Phase.finished) return;
    final left = {for (final m in _members) if (m.left) m.uid};
    final gone = [for (final p in s.alive) if (left.contains(p.uid)) p.uid];
    if (gone.isEmpty) return;

    final (ns, deaths) = s.applyDeaths([for (final u in gone) Death(u, DeathCause.abandon)]);
    final names = [for (final d in deaths) ns.player(d.uid)!.name];
    await _commit(
      state: ns,
      room: _room.copyWith(
        narration: NarrationLine(
          names.length == 1
              ? '${names.first} ha abandonado el pueblo.'
              : '${names.join(', ')} han abandonado el pueblo.',
          Cue.death,
        ),
      ),
      memberPatches: _deathPatches(deaths, ns),
    );
    final w = VictoryChecker.check(ns);
    if (w != null) await _finish(w);
  }

  /// Avance anticipado si todos los que deben actuar/votar ya lo han hecho.
  Future<void> _earlyCheck() async {
    final s = _state;
    if (!_auto || _lost || _stopped || s == null) return;
    if (_room.phase == Phase.night && _room.nightStep != null) {
      final actors = s.alivePlayersWithRole(_room.nightStep!);
      if (actors.isNotEmpty && actors.every((p) => _actions.containsKey(p.uid))) {
        await _advance();
      }
    } else if (_room.phase == Phase.voting) {
      final alive = s.alive;
      if (alive.isNotEmpty && alive.every((p) => _votes.containsKey(p.uid))) {
        await _advance();
      }
    }
  }

  // ---------------------------------------------------------- suscripciones

  void _subscribeForPhase() {
    switch (_room.phase) {
      case Phase.night:
        _subscribeActions(_room.round);
      case Phase.voting:
        _subscribeVotes(_room.voteSeq);
      default:
        break;
    }
  }

  void _subscribeActions(int round) {
    _actionsSub?.cancel();
    _actionsSub = backend.watchActions(roomId, round).listen((docs) {
      _actionIds = {for (final d in docs) d.id};
      final map = <String, NightAction>{};
      final s = _state;
      for (final d in docs) {
        if (s != null) {
          final err = ActionValidator.validate(s.copyWith(phase: Phase.night), d.action);
          if (err != null) {
            rejectedLog.add('${d.action.uid}: $err');
            continue;
          }
        }
        map[d.action.uid] = d.action;
      }
      _actions = map;
      _notify();
      _enqueue(_earlyCheck).catchError(_swallow);
    });
  }

  void _subscribeVotes(int seq) {
    _votesSub?.cancel();
    _votesSub = backend.watchVotes(roomId, seq).listen((docs) {
      _voteIds = {for (final d in docs) d.id};
      final map = <String, String>{};
      final s = _state;
      for (final d in docs) {
        if (s != null) {
          final cands = _room.voteCandidates.isEmpty ? null : _room.voteCandidates;
          if (!VoteResolver.isValidVote(s, d.uid, d.target, candidates: cands)) {
            rejectedLog.add('${d.uid}: voto inválido.');
            continue;
          }
        }
        map[d.uid] = d.target;
      }
      _votes = map;
      _notify();
      _enqueue(_earlyCheck).catchError(_swallow);
    });
  }

  // ----------------------------------------------------------------- utilidades

  Future<void> _presenceTick(DateTime t) async {
    for (final e in _presence.entries) {
      final prev = _presenceSeen[e.key];
      if (prev == null || prev.value != e.value) {
        _presenceSeen[e.key] = (value: e.value, changed: t);
      }
    }
    if (_lastPresence != null && t.difference(_lastPresence!) < timings.presenceEvery) return;
    _lastPresence = t;
    final diffs = <String, bool>{};
    for (final m in _members) {
      if (m.uid == backend.uid) continue;
      final seen = _presenceSeen[m.uid];
      final online = seen != null && t.difference(seen.changed) < timings.offlineAfter;
      if (online != m.online) diffs[m.uid] = online;
    }
    if (diffs.isNotEmpty) await backend.setOnline(roomId, diffs);
  }

  Future<void> _commitRoom(RoomDoc room) => _commit(room: room, state: _state);

  Future<void> _commit({
    required RoomDoc room,
    GameState? state,
    Map<String, PrivateDoc> privates = const {},
    Map<String, Map<String, dynamic>> memberPatches = const {},
    List<String> deleteMembers = const [],
    List<String> deleteActions = const [],
    List<String> deleteVotes = const [],
  }) async {
    final st = state ?? _state;
    try {
      final v = await backend.commit(
        roomId,
        Commit(
          expectedVersion: _version,
          room: room,
          privates: privates,
          memberPatches: memberPatches,
          deleteMembers: deleteMembers,
          hostState: st == null ? null : HostStateDoc(state: st, version: _version + 1),
          deleteActions: deleteActions,
          deleteVotes: deleteVotes,
        ),
      );
      _version = v;
      _room = room.copyWith(version: v);
      _state = st;
    } on VersionConflictException {
      _markLost();
      rethrow;
    }
    _notify();
  }

  void _arm(Duration d) {
    _deadline = _auto ? _now().add(d) : null;
    _notify();
  }

  void _requirePhase(Phase p) {
    if (_room.phase != p) {
      throw StateError('Acción no permitida en la fase ${_room.phase.name}.');
    }
  }

  void _markLost() {
    if (_lost) return;
    _lost = true;
    _deadline = null;
    _notify();
    onLost?.call();
  }

  void _notify() {
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  void _swallow(Object e, [StackTrace? st]) {}

  Future<void> _enqueue(Future<void> Function() f) {
    final c = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await f();
        c.complete();
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }
}
