import 'dart:math';

import 'config.dart';
import 'enums.dart';
import 'game_state.dart';

/// Valor de voto para abstenerse.
const String kAbstain = 'abstain';

class VoteOutcome {
  const VoteOutcome({
    required this.tally,
    required this.abstentions,
    required this.eliminated,
    required this.tied,
    required this.needsRevote,
    required this.validVotes,
    required this.state,
    required this.deaths,
  });

  /// Votos recibidos por objetivo.
  final Map<String, int> tally;
  final int abstentions;

  /// Jugador eliminado (null si nadie).
  final String? eliminated;

  /// Empatados en cabeza (si hubo empate).
  final List<String> tied;

  /// El empate se resuelve con una segunda votación entre [tied].
  final bool needsRevote;

  /// Votos aceptados: votante -> objetivo (o [kAbstain]).
  final Map<String, String> validVotes;

  /// Estado tras la eliminación (sin cambios si no hubo eliminado).
  final GameState state;
  final List<Death> deaths;
}

class VoteResolver {
  const VoteResolver._();

  /// ¿Es válido el voto de [voter] a [target]?
  static bool isValidVote(
    GameState s,
    String voter,
    String target, {
    List<String>? candidates,
  }) {
    final v = s.player(voter);
    if (v == null || !v.alive) return false;
    if (target == kAbstain) return s.config.allowAbstain;
    if (target == voter) return false;
    final t = s.player(target);
    if (t == null || !t.alive) return false;
    if (candidates != null && !candidates.contains(target)) return false;
    return true;
  }

  static VoteOutcome resolve(
    GameState state,
    Map<String, String> votes,
    Random rng, {
    List<String>? candidates,
    bool isRevote = false,
  }) {
    final GameConfig cfg = state.config;
    final valid = <String, String>{};
    final tally = <String, int>{};
    var abstentions = 0;
    for (final e in votes.entries) {
      if (!isValidVote(state, e.key, e.value, candidates: candidates)) continue;
      valid[e.key] = e.value;
      if (e.value == kAbstain) {
        abstentions++;
      } else {
        tally.update(e.value, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    String? eliminated;
    var tied = <String>[];
    var needsRevote = false;
    if (tally.isNotEmpty) {
      final top = tally.values.reduce(max);
      tied = [for (final e in tally.entries) if (e.value == top) e.key]..sort();
      if (tied.length == 1) {
        eliminated = tied.first;
        tied = [];
      } else {
        switch (cfg.tieRule) {
          case TieRule.noElimination:
            break;
          case TieRule.revote:
            if (!isRevote) needsRevote = true;
            break;
          case TieRule.random:
            eliminated = tied[rng.nextInt(tied.length)];
            break;
        }
      }
    }

    // Duelo sin salida: quedan 2 vivos y ninguno puede matar de noche (no queda
    // ningún Asesino; p. ej. La Puta del bando asesino contra un civil con
    // mayoría estricta). Cada uno sólo puede votar al otro => empate perpetuo.
    // Para que la partida no dure eternamente, se resuelve al azar.
    final alive = state.alive;
    final deadlockedDuel =
        alive.length == 2 && alive.every((p) => p.role != RoleId.assassin);
    if (deadlockedDuel && eliminated == null) {
      final pool = tied.length > 1
          ? tied
          : ([for (final p in alive) p.uid]..sort());
      eliminated = pool[rng.nextInt(pool.length)];
      tied = [];
      needsRevote = false;
    }

    var newState = state;
    var deaths = <Death>[];
    if (eliminated != null) {
      final r = state.applyDeaths([Death(eliminated, DeathCause.vote)]);
      newState = r.$1;
      deaths = r.$2;
    }
    return VoteOutcome(
      tally: tally,
      abstentions: abstentions,
      eliminated: eliminated,
      tied: tied,
      needsRevote: needsRevote,
      validVotes: valid,
      state: newState,
      deaths: deaths,
    );
  }
}
