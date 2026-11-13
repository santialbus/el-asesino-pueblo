/// Identificadores de rol.
enum RoleId { assassin, police, doctor, cupid, blocker, civilian }

/// Equipo de victoria. [neutral] cuenta como "no asesino" para la paridad
/// pero no pertenece al pueblo (p. ej. un Cupido neutral).
enum Team { town, assassins, neutral }

/// Fases de la máquina de estados.
enum Phase {
  lobby,
  roleReveal,
  night,
  dawn,
  discussion,
  voting,
  voteResult,
  victoryCheck,
  nextRound,
  finished,
}

enum NarratorMode { auto, human }

/// Qué ocurre si la votación termina en empate.
enum TieRule { noElimination, revote, random }

enum Winner { town, assassins, lovers }

enum DeathCause { assassin, heartbreak, vote, abandon }

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
