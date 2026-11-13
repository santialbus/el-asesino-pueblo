import 'enums.dart';
import 'game_state.dart';

/// Acción nocturna enviada por un jugador. [targets] vacío = pasar.
class NightAction {
  const NightAction({
    required this.uid,
    required this.round,
    required this.role,
    required this.targets,
    this.opId = '',
  });

  final String uid;
  final int round;
  final RoleId role;
  final List<String> targets;

  /// Identificador único de operación (idempotencia / reintentos seguros).
  final String opId;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'round': round,
        'role': role.name,
        'targets': targets,
        'opId': opId,
      };

  factory NightAction.fromMap(Map<String, dynamic> m) => NightAction(
        uid: m['uid'] as String,
        round: (m['round'] as num).toInt(),
        role: enumByName(RoleId.values, m['role'], RoleId.civilian),
        targets: [for (final t in (m['targets'] as List? ?? const [])) t as String],
        opId: m['opId'] as String? ?? '',
      );
}

/// Comprueba que una acción es legal en el estado dado. Devuelve `null` si es
/// válida o un mensaje de error en español.
class ActionValidator {
  const ActionValidator._();

  static String? validate(GameState s, NightAction a) {
    if (s.phase != Phase.night) return 'No es de noche.';
    if (a.round != s.round) return 'La acción pertenece a otra ronda.';
    final actor = s.player(a.uid);
    if (actor == null) return 'Jugador desconocido.';
    if (!actor.alive) return 'Un jugador eliminado no puede actuar.';
    if (actor.role != a.role) return 'Ese jugador no tiene ese rol.';
    if (!s.config.activeNightRoles().contains(a.role)) {
      return 'Ese rol no actúa en esta partida.';
    }
    if (a.role == RoleId.cupid && (s.round != 1 || s.lovers.isNotEmpty)) {
      return 'Cupido sólo actúa la primera noche.';
    }
    if (a.targets.isEmpty) return null; // pasar

    final expected = a.role == RoleId.cupid ? 2 : 1;
    if (a.targets.length != expected) {
      return 'Número de objetivos incorrecto (se esperan $expected).';
    }
    if (a.targets.toSet().length != a.targets.length) return 'Objetivos repetidos.';
    for (final t in a.targets) {
      final p = s.player(t);
      if (p == null) return 'Objetivo desconocido.';
      if (!p.alive) return 'El objetivo ya está eliminado.';
    }
    final t = a.targets.first;
    switch (a.role) {
      case RoleId.assassin:
        if (t == a.uid) return 'Un asesino no puede atacarse a sí mismo.';
        if (s.isAssassinTeam(t)) return 'Un asesino no puede atacar a su equipo.';
        return null;
      case RoleId.police:
        return t == a.uid ? 'No puedes investigarte a ti mismo.' : null;
      case RoleId.blocker:
        return t == a.uid ? 'No puedes distraerte a ti misma.' : null;
      case RoleId.doctor:
        if (t == a.uid && !s.config.doctorSelfProtect) {
          return 'El médico no puede protegerse a sí mismo.';
        }
        if (!s.config.doctorRepeatProtect && s.lastProtected[a.uid] == t) {
          return 'No puedes proteger al mismo jugador dos noches seguidas.';
        }
        return null;
      case RoleId.cupid:
        if (!s.config.cupidSelfPick && a.targets.contains(a.uid)) {
          return 'Cupido no puede elegirse a sí mismo.';
        }
        return null;
      case RoleId.civilian:
        return 'El civil no tiene habilidad nocturna.';
    }
  }

  /// Objetivos legales para una acción de [uid] (para la interfaz).
  static List<String> validTargets(GameState s, String uid) {
    final p = s.player(uid);
    if (p == null || !p.alive) return const [];
    final out = <String>[];
    for (final q in s.alive) {
      final probe = NightAction(
        uid: uid,
        round: s.round,
        role: p.role,
        targets: p.role == RoleId.cupid ? [q.uid, q.uid] : [q.uid],
      );
      if (p.role == RoleId.cupid) {
        // Para Cupido basta con que el jugador sea elegible individualmente.
        if (q.uid == uid && !s.config.cupidSelfPick) continue;
        out.add(q.uid);
      } else if (validate(s.copyWith(phase: Phase.night), probe) == null) {
        out.add(q.uid);
      }
    }
    return out;
  }
}
