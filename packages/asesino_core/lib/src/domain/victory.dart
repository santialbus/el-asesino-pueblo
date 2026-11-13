import 'enums.dart';
import 'game_state.dart';

/// Comprueba las condiciones de victoria.
///
/// * Pueblo: no queda ningún asesino vivo.
/// * Asesinos: asesinos vivos >= resto de vivos (o `>` con mayoría estricta).
/// * Enamorados (opcional): sólo quedan los dos enamorados y son de
///   equipos distintos (uno asesino y otro no).
class VictoryChecker {
  const VictoryChecker._();

  static Winner? check(GameState s) {
    final alive = s.alive;
    final assassinsAlive = alive.where((p) => s.isAssassinTeam(p.uid)).length;
    final others = alive.length - assassinsAlive;

    if (s.config.loversSpecialWin && s.lovers.length == 2 && alive.length == 2) {
      final uids = alive.map((p) => p.uid).toSet();
      if (uids.containsAll(s.lovers)) {
        final a = s.isAssassinTeam(s.lovers[0]);
        final b = s.isAssassinTeam(s.lovers[1]);
        if (a != b) return Winner.lovers;
      }
    }
    if (assassinsAlive == 0) return Winner.town;
    final assassinsWin = s.config.assassinsNeedStrictMajority
        ? assassinsAlive > others
        : assassinsAlive >= others;
    if (assassinsWin) return Winner.assassins;
    return null;
  }
}
