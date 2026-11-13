import 'dart:math';

import '../domain/actions.dart';
import '../domain/enums.dart';
import 'backend.dart';
import 'docs.dart';

/// Qué debe mostrar la interfaz de un jugador durante la noche.
class NightPrompt {
  const NightPrompt({
    required this.myTurn,
    required this.role,
    required this.picks,
    required this.validTargets,
    required this.isActor,
  });

  /// Es el turno de mi rol.
  final bool myTurn;
  final RoleId? role;

  /// Cuántos objetivos hay que elegir (2 para Cupido).
  final int picks;
  final List<String> validTargets;

  /// Mi rol tiene habilidad en esta noche y estoy vivo.
  final bool isActor;

  static const none = NightPrompt(
    myTurn: false,
    role: null,
    picks: 0,
    validTargets: [],
    isActor: false,
  );

  /// Calcula el estado de la pantalla nocturna únicamente con información
  /// legítima para este jugador: sala pública, miembros y su documento privado.
  static NightPrompt compute({
    required RoomDoc room,
    required List<MemberDoc> members,
    required PrivateDoc? me,
    required String myUid,
  }) {
    if (room.phase != Phase.night || me == null) return none;
    final self = members.where((m) => m.uid == myUid);
    if (self.isEmpty || !self.first.alive) return none;
    final role = me.role;
    final steps = room.config.nightSteps(room.round);
    final hasAbility = steps.contains(role);
    final myTurn = hasAbility && room.nightStep == role;
    if (!hasAbility) return NightPrompt(myTurn: false, role: role, picks: 0, validTargets: const [], isActor: false);

    final alive = [for (final m in members) if (m.alive && !m.isNarrator) m.uid];
    final targets = <String>[];
    for (final u in alive) {
      switch (role) {
        case RoleId.assassin:
          if (u == myUid || me.teammates.contains(u)) continue;
          break;
        case RoleId.police:
        case RoleId.blocker:
          if (u == myUid) continue;
          break;
        case RoleId.doctor:
          if (u == myUid && !room.config.doctorSelfProtect) continue;
          if (!room.config.doctorRepeatProtect && me.lastProtected == u) continue;
          break;
        case RoleId.cupid:
          if (u == myUid && !room.config.cupidSelfPick) continue;
          break;
        case RoleId.civilian:
          continue;
      }
      targets.add(u);
    }
    return NightPrompt(
      myTurn: myTurn,
      role: role,
      picks: role == RoleId.cupid ? 2 : 1,
      validTargets: targets,
      isActor: true,
    );
  }
}

/// Detecta anfitriones inactivos sin depender de relojes sincronizados:
/// mide cuánto tiempo local ha pasado desde que cambió el latido.
class HostWatchdog {
  HostWatchdog({
    DateTime Function()? now,
    this.staleAfter = const Duration(seconds: 75),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration staleAfter;
  int _lastBeat = -1;
  String? _host;
  late DateTime _lastChange = _now();

  void onRoom(RoomDoc room) {
    if (room.hostUid != _host || room.hostHeartbeatMs != _lastBeat) {
      _host = room.hostUid;
      _lastBeat = room.hostHeartbeatMs;
      _lastChange = _now();
    }
  }

  bool get hostStale =>
      _host != null && _now().difference(_lastChange) > staleAfter;
}

/// Envío de acciones y votos desde el dispositivo del jugador.
class PlayerActions {
  PlayerActions(this.backend, this.roomId, {Random? rng}) : _rng = rng ?? Random();
  final GameBackend backend;
  final String roomId;
  final Random _rng;

  String _opId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rng.nextInt(1 << 20).toRadixString(36)}';

  Future<void> submitNight(RoomDoc room, RoleId role, List<String> targets) =>
      backend.submitAction(
        roomId,
        NightAction(
          uid: backend.uid,
          round: room.round,
          role: role,
          targets: targets,
          opId: _opId(),
        ),
      );

  Future<void> submitVote(RoomDoc room, String target) => backend.submitVote(
        roomId,
        VoteDoc(uid: backend.uid, seq: room.voteSeq, target: target),
      );
}
