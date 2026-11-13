import 'dart:math';

import 'config.dart';
import 'enums.dart';

/// Reparto aleatorio de roles. La aleatoriedad llega por [Random] inyectado:
/// con la misma semilla el reparto es idéntico (pruebas deterministas).
class RoleAssigner {
  const RoleAssigner._();

  /// Lista de roles (sin barajar) que corresponde a [players] jugadores.
  static List<RoleId> roleBag(GameConfig config, int players) {
    final errors = config.validate(players);
    if (errors.isNotEmpty) {
      throw ArgumentError('Configuración inválida: ${errors.join(' ')}');
    }
    final bag = <RoleId>[
      for (var i = 0; i < config.assassins; i++) RoleId.assassin,
      for (var i = 0; i < config.police; i++) RoleId.police,
      for (var i = 0; i < config.doctors; i++) RoleId.doctor,
      if (config.cupid) RoleId.cupid,
      if (config.blocker) RoleId.blocker,
    ];
    final civilians = config.civilians(players);
    for (var i = 0; i < civilians; i++) {
      bag.add(RoleId.civilian);
    }
    assert(bag.length == players);
    return bag;
  }

  /// Asigna un rol a cada uid. El orden de [uids] no influye en el reparto
  /// (se ordenan antes de barajar).
  static Map<String, RoleId> assign(List<String> uids, GameConfig config, Random rng) {
    final bag = roleBag(config, uids.length)..shuffle(rng);
    final sorted = [...uids]..sort();
    return {for (var i = 0; i < sorted.length; i++) sorted[i]: bag[i]};
  }
}
