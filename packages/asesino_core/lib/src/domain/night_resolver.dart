import 'dart:math';

import 'actions.dart';
import 'enums.dart';
import 'game_state.dart';

class NightOutcome {
  const NightOutcome({
    required this.deaths,
    required this.newLovers,
    required this.investigations,
    required this.newLastProtected,
    required this.saved,
    required this.blockedUid,
    required this.rejected,
    required this.state,
  });

  /// Muertes efectivas (incluye cadena de enamorados).
  final List<Death> deaths;
  final List<String> newLovers;
  final List<Investigation> investigations;
  final Map<String, String> newLastProtected;

  /// Víctima salvada por un médico (para anuncio opcional, sin identificarla).
  final String? saved;
  final String? blockedUid;

  /// Acciones descartadas por inválidas o duplicadas.
  final List<String> rejected;

  /// Estado resultante (con muertes, enamorados e investigaciones aplicados).
  final GameState state;
}

/// Resuelve las acciones de una noche. Es una función pura: mismas entradas
/// (estado, acciones y semilla del [Random]) => mismo resultado.
///
/// Orden de resolución fijo:
/// 1. Bloqueo (La Puta).  2. Cupido.  3. Investigaciones.  4. Protecciones.
/// 5. Ataque asesino.  6. Cadena de enamorados.
class NightResolver {
  const NightResolver._();

  static NightOutcome resolve(GameState state, List<NightAction> actions, Random rng) {
    final rejected = <String>[];
    final seen = <String>{};
    final valid = <NightAction>[];
    final sorted = [...actions]..sort((a, b) {
        final c = a.uid.compareTo(b.uid);
        return c != 0 ? c : a.role.index.compareTo(b.role.index);
      });
    for (final a in sorted) {
      final err = ActionValidator.validate(state, a);
      if (err != null) {
        rejected.add('${a.uid}: $err');
        continue;
      }
      if (!seen.add(a.uid)) {
        rejected.add('${a.uid}: acción duplicada.');
        continue;
      }
      valid.add(a);
    }

    // 1. Bloqueo
    String? blockedUid;
    for (final a in valid) {
      if (a.role == RoleId.blocker && a.targets.isNotEmpty) blockedUid = a.targets.first;
    }
    bool isBlocked(NightAction a) {
      if (blockedUid == null || a.uid != blockedUid) return false;
      if (a.role == RoleId.blocker) return false;
      return state.config.blockable.contains(a.role);
    }

    // 2. Cupido
    var newLovers = <String>[];
    for (final a in valid) {
      if (a.role == RoleId.cupid && a.targets.length == 2 && !isBlocked(a)) {
        newLovers = [...a.targets]..sort();
      }
    }

    // 3. Investigaciones
    final investigations = <Investigation>[];
    for (final a in valid) {
      if (a.role != RoleId.police || a.targets.isEmpty) continue;
      final t = a.targets.first;
      final blocked = isBlocked(a);
      investigations.add(Investigation(
        police: a.uid,
        round: state.round,
        target: t,
        isAssassin: !blocked && state.isAssassinTeam(t),
        blocked: blocked,
      ));
    }

    // 4. Protecciones
    final protectedUids = <String>{};
    final newLastProtected = <String, String>{};
    for (final a in valid) {
      if (a.role != RoleId.doctor) continue;
      if (a.targets.isEmpty) {
        newLastProtected.remove(a.uid);
        continue;
      }
      newLastProtected[a.uid] = a.targets.first;
      if (!isBlocked(a)) protectedUids.add(a.targets.first);
    }

    // 5. Ataque asesino (voto mayoritario; empate resuelto con el Random)
    final votes = <String, int>{};
    for (final a in valid) {
      if (a.role != RoleId.assassin || a.targets.isEmpty || isBlocked(a)) continue;
      votes.update(a.targets.first, (v) => v + 1, ifAbsent: () => 1);
    }
    String? victim;
    if (votes.isNotEmpty) {
      final top = votes.values.reduce(max);
      final tied = [for (final e in votes.entries) if (e.value == top) e.key]..sort();
      victim = tied.length == 1 ? tied.first : tied[rng.nextInt(tied.length)];
    }
    String? saved;
    final initialDeaths = <Death>[];
    if (victim != null) {
      if (protectedUids.contains(victim)) {
        saved = victim;
      } else {
        initialDeaths.add(Death(victim, DeathCause.assassin));
      }
    }

    // 6. Cadena de enamorados (los enamorados de esta noche ya cuentan)
    final withLovers = newLovers.isEmpty
        ? state
        : state.copyWith(
            lovers: newLovers,
            cupidUid: valid
                .firstWhere((a) => a.role == RoleId.cupid && a.targets.length == 2)
                .uid,
          );
    final (afterDeaths, deaths) = withLovers.applyDeaths(initialDeaths);

    final mergedProtected = {...state.lastProtected, ...newLastProtected};
    for (final a in valid) {
      if (a.role == RoleId.doctor && a.targets.isEmpty) mergedProtected.remove(a.uid);
    }
    final finalState = afterDeaths.copyWith(
      lastProtected: mergedProtected,
      investigations: [...state.investigations, ...investigations],
    );

    return NightOutcome(
      deaths: deaths,
      newLovers: newLovers,
      investigations: investigations,
      newLastProtected: newLastProtected,
      saved: saved,
      blockedUid: blockedUid,
      rejected: rejected,
      state: finalState,
    );
  }
}
