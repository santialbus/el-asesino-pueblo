import 'config.dart';
import 'enums.dart';

/// Muerte producida en una resolución.
class Death {
  const Death(this.uid, this.cause);
  final String uid;
  final DeathCause cause;

  Map<String, dynamic> toMap() => {'uid': uid, 'cause': cause.name};
  factory Death.fromMap(Map<String, dynamic> m) => Death(
        m['uid'] as String,
        enumByName(DeathCause.values, m['cause'], DeathCause.assassin),
      );
}

class PlayerState {
  const PlayerState({
    required this.uid,
    required this.name,
    required this.role,
    this.alive = true,
    this.deathCause,
    this.deathRound,
  });

  final String uid;
  final String name;
  final RoleId role;
  final bool alive;
  final DeathCause? deathCause;
  final int? deathRound;

  PlayerState kill(DeathCause cause, int round) => PlayerState(
        uid: uid,
        name: name,
        role: role,
        alive: false,
        deathCause: cause,
        deathRound: round,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'role': role.name,
        'alive': alive,
        if (deathCause != null) 'deathCause': deathCause!.name,
        if (deathRound != null) 'deathRound': deathRound,
      };

  factory PlayerState.fromMap(Map<String, dynamic> m) => PlayerState(
        uid: m['uid'] as String,
        name: m['name'] as String,
        role: enumByName(RoleId.values, m['role'], RoleId.civilian),
        alive: m['alive'] as bool? ?? true,
        deathCause: m['deathCause'] == null
            ? null
            : enumByName(DeathCause.values, m['deathCause'], DeathCause.assassin),
        deathRound: (m['deathRound'] as num?)?.toInt(),
      );
}

/// Resultado de una investigación policial.
class Investigation {
  const Investigation({
    required this.police,
    required this.round,
    required this.target,
    required this.isAssassin,
    required this.blocked,
  });

  final String police;
  final int round;
  final String target;
  final bool isAssassin;

  /// La investigación fue bloqueada: no hay resultado.
  final bool blocked;

  Map<String, dynamic> toMap() => {
        'police': police,
        'round': round,
        'target': target,
        'isAssassin': isAssassin,
        'blocked': blocked,
      };

  factory Investigation.fromMap(Map<String, dynamic> m) => Investigation(
        police: m['police'] as String,
        round: (m['round'] as num).toInt(),
        target: m['target'] as String,
        isAssassin: m['isAssassin'] as bool? ?? false,
        blocked: m['blocked'] as bool? ?? false,
      );
}

/// Estado completo y autoritativo de la partida (vive en el anfitrión y se
/// guarda en `hostState` para recuperación). Contiene los roles secretos.
class GameState {
  const GameState({
    required this.config,
    required this.phase,
    required this.round,
    required this.players,
    this.lovers = const [],
    this.cupidUid,
    this.lastProtected = const {},
    this.investigations = const [],
    this.winner,
  });

  final GameConfig config;
  final Phase phase;
  final int round;
  final List<PlayerState> players;
  final List<String> lovers;
  final String? cupidUid;

  /// Último objetivo protegido por cada médico (uid médico -> uid objetivo).
  final Map<String, String> lastProtected;
  final List<Investigation> investigations;
  final Winner? winner;

  PlayerState? player(String uid) {
    for (final p in players) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  List<PlayerState> get alive => [for (final p in players) if (p.alive) p];

  Team teamOf(String uid) {
    final p = player(uid);
    if (p == null) return Team.town;
    switch (p.role) {
      case RoleId.assassin:
        return Team.assassins;
      case RoleId.cupid:
        return config.cupidTeam;
      case RoleId.blocker:
        return config.blockerTeam;
      case RoleId.police:
      case RoleId.doctor:
      case RoleId.civilian:
        return Team.town;
    }
  }

  bool isAssassinTeam(String uid) => teamOf(uid) == Team.assassins;

  List<PlayerState> alivePlayersWithRole(RoleId role) =>
      [for (final p in players) if (p.alive && p.role == role) p];

  /// Aplica muertes (incluida la cadena de enamorados). Devuelve el nuevo
  /// estado y la lista completa de muertes efectivas.
  (GameState, List<Death>) applyDeaths(List<Death> initial) {
    final deaths = <Death>[];
    var updated = [...players];
    void kill(String uid, DeathCause cause) {
      final i = updated.indexWhere((p) => p.uid == uid);
      if (i < 0 || !updated[i].alive) return;
      updated[i] = updated[i].kill(cause, round);
      deaths.add(Death(uid, cause));
    }

    for (final d in initial) {
      kill(d.uid, d.cause);
    }
    // Cadena de enamorados (sólo hay una pareja, basta una pasada por muerto).
    if (lovers.length == 2) {
      for (final d in [...deaths]) {
        if (lovers.contains(d.uid)) {
          final other = lovers.firstWhere((u) => u != d.uid);
          kill(other, DeathCause.heartbreak);
        }
      }
    }
    return (copyWith(players: updated), deaths);
  }

  GameState copyWith({
    GameConfig? config,
    Phase? phase,
    int? round,
    List<PlayerState>? players,
    List<String>? lovers,
    String? cupidUid,
    Map<String, String>? lastProtected,
    List<Investigation>? investigations,
    Winner? winner,
    bool clearWinner = false,
  }) =>
      GameState(
        config: config ?? this.config,
        phase: phase ?? this.phase,
        round: round ?? this.round,
        players: players ?? this.players,
        lovers: lovers ?? this.lovers,
        cupidUid: cupidUid ?? this.cupidUid,
        lastProtected: lastProtected ?? this.lastProtected,
        investigations: investigations ?? this.investigations,
        winner: clearWinner ? null : (winner ?? this.winner),
      );

  Map<String, dynamic> toMap() => {
        'config': config.toMap(),
        'phase': phase.name,
        'round': round,
        'players': [for (final p in players) p.toMap()],
        'lovers': lovers,
        if (cupidUid != null) 'cupidUid': cupidUid,
        'lastProtected': lastProtected,
        'investigations': [for (final i in investigations) i.toMap()],
        if (winner != null) 'winner': winner!.name,
      };

  factory GameState.fromMap(Map<String, dynamic> m) => GameState(
        config: GameConfig.fromMap(Map<String, dynamic>.from(m['config'] as Map)),
        phase: enumByName(Phase.values, m['phase'], Phase.lobby),
        round: (m['round'] as num).toInt(),
        players: [
          for (final p in (m['players'] as List))
            PlayerState.fromMap(Map<String, dynamic>.from(p as Map))
        ],
        lovers: [for (final u in (m['lovers'] as List? ?? const [])) u as String],
        cupidUid: m['cupidUid'] as String?,
        lastProtected: {
          for (final e in ((m['lastProtected'] as Map?) ?? const {}).entries)
            e.key as String: e.value as String
        },
        investigations: [
          for (final i in (m['investigations'] as List? ?? const []))
            Investigation.fromMap(Map<String, dynamic>.from(i as Map))
        ],
        winner: m['winner'] == null
            ? null
            : enumByName(Winner.values, m['winner'], Winner.town),
      );
}

/// Máquina de estados explícita de la partida.
///
/// Transiciones válidas (condición entre paréntesis):
/// ```
/// lobby        -> roleReveal   (config válida, 5..20 jugadores)
/// roleReveal   -> night
/// night        -> dawn         (todos los pasos nocturnos resueltos)
/// dawn         -> victoryCheck
/// victoryCheck -> finished     (hay ganador)
/// victoryCheck -> discussion   (viene del amanecer, sin ganador)
/// victoryCheck -> nextRound    (viene de una votación, sin ganador)
/// discussion   -> voting
/// voting       -> voteResult
/// voteResult   -> voting       (empate con repetición de votación)
/// voteResult   -> victoryCheck
/// nextRound    -> night        (ronda + 1)
/// ```
class PhaseMachine {
  const PhaseMachine._();

  static const Map<Phase, Set<Phase>> _allowed = {
    Phase.lobby: {Phase.roleReveal},
    Phase.roleReveal: {Phase.night},
    Phase.night: {Phase.dawn},
    Phase.dawn: {Phase.victoryCheck},
    Phase.victoryCheck: {Phase.finished, Phase.discussion, Phase.nextRound},
    Phase.discussion: {Phase.voting},
    Phase.voting: {Phase.voteResult},
    Phase.voteResult: {Phase.voting, Phase.victoryCheck},
    Phase.nextRound: {Phase.night},
    Phase.finished: {Phase.lobby},
  };

  static bool canTransition(Phase from, Phase to) {
    if (to == Phase.finished && from != Phase.lobby) return true; // abortar
    return _allowed[from]?.contains(to) ?? false;
  }

  /// Fase siguiente tras [victoryCheck].
  static Phase afterVictoryCheck({required bool hasWinner, required bool fromDawn}) {
    if (hasWinner) return Phase.finished;
    return fromDawn ? Phase.discussion : Phase.nextRound;
  }
}
