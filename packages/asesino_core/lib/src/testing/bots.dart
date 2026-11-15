import 'dart:async';
import 'dart:math';

import '../application/backend.dart';
import '../application/docs.dart';
import '../application/player_view.dart';
import '../domain/enums.dart';
import '../domain/vote_resolver.dart';

/// Jugador simulado. Usa exactamente la misma lógica que un jugador real
/// ([NightPrompt], [PlayerActions]) a través de su propio [GameBackend], de
/// modo que ejercita el mismo camino de código y las mismas reglas.
class BotPlayer {
  BotPlayer(this.backend, this.roomId, this.rng) {
    _subs.add(backend.watchRoom(roomId).listen((r) => room = r, onError: (_) {}));
    _subs.add(backend.watchMembers(roomId).listen((m) => members = m, onError: (_) {}));
    _subs.add(backend.watchPrivate(roomId, backend.uid).listen((p) => me = p, onError: (_) {}));
  }

  final GameBackend backend;
  final String roomId;
  final Random rng;
  final List<StreamSubscription<Object?>> _subs = [];
  final Set<String> _done = {};

  RoomDoc? room;
  List<MemberDoc> members = const [];
  PrivateDoc? me;

  /// Probabilidad de pasar sin actuar de noche (10 %).
  bool passSometimes = true;

  /// Jugadores a los que este bot nunca ataca ni vota (p. ej. en el tutorial,
  /// para que la persona no sea eliminada antes de aprender).
  Set<String> spare = {};

  /// Si es true, escribe frases sueltas en el chat durante el debate.
  bool chatty = true;
  final Set<String> _chatted = {};

  String get uid => backend.uid;

  MemberDoc? get self {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  /// Olvida lo ya hecho (p. ej. al empezar otra partida).
  void reset() {
    _done.clear();
    _chatted.clear();
  }

  /// Si toca actuar o votar y aún no lo ha hecho, lo hace. Idempotente.
  Future<void> act() async {
    final r = room;
    final s = self;
    if (r == null || s == null || !s.alive || s.left || s.isNarrator) return;
    final actions = PlayerActions(backend, roomId, rng: rng);

    if (r.phase == Phase.night && r.nightStep != null) {
      final p = NightPrompt.compute(room: r, members: members, me: me, myUid: uid);
      final key = 'n${r.round}_${r.nightStep!.name}';
      if (p.myTurn && !_done.contains(key)) {
        _done.add(key);
        final pool = [for (final t in p.validTargets) if (!spare.contains(t)) t]..shuffle(rng);
        final pass = passSometimes && rng.nextInt(10) == 0;
        final picks = (pass || pool.length < p.picks) ? <String>[] : pool.take(p.picks).toList();
        await actions.submitNight(r, p.role!, picks);
      }
    } else if (r.phase == Phase.discussion) {
      final key = 'c${r.round}';
      if (chatty && !_chatted.contains(key)) {
        _chatted.add(key);
        if (rng.nextInt(100) < 55) {
          final others = [for (final m in members) if (m.alive && m.uid != uid && !m.isNarrator) m.name];
          final who = others.isEmpty ? 'alguien' : others[rng.nextInt(others.length)];
          final line = kBotPhrases[rng.nextInt(kBotPhrases.length)].replaceAll('{n}', who);
          await backend.sendChat(roomId, line);
        }
      }
    } else if (r.phase == Phase.voting) {
      final key = 'v${r.voteSeq}';
      if (!_done.contains(key)) {
        _done.add(key);
        final cands = r.voteCandidates.isNotEmpty
            ? r.voteCandidates.where((u) => u != uid && !spare.contains(u)).toList()
            : [
                for (final m in members)
                  if (m.alive && m.uid != uid && !m.isNarrator && !m.left && !spare.contains(m.uid)) m.uid
              ];
        final abstain = r.config.allowAbstain && (cands.isEmpty || rng.nextInt(12) == 0);
        if (abstain) {
          await actions.submitVote(r, kAbstain);
        } else if (cands.isNotEmpty) {
          await actions.submitVote(r, cands[rng.nextInt(cands.length)]);
        }
      }
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
  }
}

/// Hace jugar a un grupo de bots con retardos aleatorios para que la partida
/// se sienta natural (los bots no actúan todos en el mismo instante).
class BotDriver {
  BotDriver(this.bots, {Random? rng, this.every = const Duration(milliseconds: 700), this.chance = 0.4})
      : _rng = rng ?? Random();

  final List<BotPlayer> bots;
  final Random _rng;
  final Duration every;

  /// Probabilidad de que cada bot actúe en cada pulso.
  final double chance;
  Timer? _timer;
  bool _busy = false;
  int _pulses = 0;

  void start() {
    _beat();
    _timer ??= Timer.periodic(every, (_) => pulse());
  }

  /// Latido de presencia de los bots (aparecen como conectados al anfitrión).
  Future<void> _beat() async {
    for (final b in bots) {
      try {
        await b.backend.heartbeat(b.roomId, asHost: false);
      } catch (_) {}
    }
  }

  /// Un pulso del conductor (público para poder probarlo sin temporizador).
  Future<void> pulse({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    try {
      if (_pulses++ % 40 == 39) await _beat();
      for (final b in bots) {
        if (force || _rng.nextDouble() < chance) {
          try {
            await b.act();
          } catch (_) {
            // Un bot que falla (p. ej. regla denegada) no detiene al resto.
          }
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    for (final b in bots) {
      await b.dispose();
    }
  }
}

/// Nombres de los bots.
const List<String> kBotNames = [
  'Marta', 'Luis', 'Carmen', 'Pablo', 'Lucía', 'Jorge',
  'Elena', 'Diego', 'Sofía', 'Álvaro', 'Irene', 'Hugo',
  'Nuria', 'Iván', 'Paula', 'Raúl', 'Clara', 'Óscar', 'Inés',
];

/// Frases de los bots en el chat ({n} = nombre de otro jugador).
const List<String> kBotPhrases = [
  'Yo no he sido, os lo juro.',
  '¿No os parece que {n} está muy callado?',
  'Yo sospecho de {n}.',
  'Anoche no oí nada raro...',
  '{n}, ¿tú dónde estabas?',
  'Mejor no votemos a la ligera.',
  'Yo confío en {n}.',
  'Esto huele a asesino cerca de {n}.',
];
