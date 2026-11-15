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
  ///
  /// [forced] fija el rol de algunos jugadores (p. ej. el tutorial, para que
  /// la persona juegue de Policía). Cada rol forzado se retira de la bolsa y el
  /// resto se baraja entre los demás; si un rol no está en la bolsa, lanza.
  static Map<String, RoleId> assign(
    List<String> uids,
    GameConfig config,
    Random rng, {
    Map<String, RoleId> forced = const {},
  }) {
    final bag = roleBag(config, uids.length);
    final result = <String, RoleId>{};
    for (final e in forced.entries) {
      if (!uids.contains(e.key)) {
        throw ArgumentError('Rol forzado para un jugador desconocido: ${e.key}');
      }
      if (!bag.remove(e.value)) {
        throw ArgumentError('El rol forzado ${e.value.name} no está disponible en la configuración.');
      }
      result[e.key] = e.value;
    }
    bag.shuffle(rng);
    final rest = [for (final u in uids) if (!forced.containsKey(u)) u]..sort();
    for (var i = 0; i < rest.length; i++) {
      result[rest[i]] = bag[i];
    }
    return result;
  }
}
