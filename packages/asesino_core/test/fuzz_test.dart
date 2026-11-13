import 'dart:math';

import 'package:asesino_core/asesino_core.dart';
import 'package:test/test.dart';

import 'support/world.dart';

/// Partidas con tamaño, reglas y semilla aleatorios: ninguna debe atascarse
/// ni violar invariantes.
void main() {
  test('60 partidas aleatorias terminan y respetan los invariantes', () async {
    final meta = Random(2026);
    for (var g = 0; g < 60; g++) {
      final n = 5 + meta.nextInt(16);
      final base = GameConfig.recommended(n);
      final cfg = base.copyWith(
        tieRule: TieRule.values[meta.nextInt(3)],
        secretVotes: meta.nextBool(),
        allowAbstain: meta.nextBool(),
        doctorSelfProtect: meta.nextBool(),
        doctorRepeatProtect: meta.nextBool(),
        cupidSelfPick: meta.nextBool(),
        assassinsNeedStrictMajority: meta.nextBool(),
        loversSpecialWin: meta.nextBool(),
        revealRoleOnDeath: meta.nextBool(),
        cupid: n >= 8 ? meta.nextBool() : false,
        blocker: n >= 8 ? meta.nextBool() : false,
        cupidTeam: meta.nextBool() ? Team.town : Team.neutral,
        blockerTeam: meta.nextBool() ? Team.town : Team.assassins,
      );
      if (cfg.validate(n).isNotEmpty) continue;
      final human = meta.nextInt(4) == 0;
      final w = await World.create(
        n,
        config: cfg,
        seed: 1000 + g,
        narrator: human ? NarratorMode.human : NarratorMode.auto,
        hostPlays: true,
      );
      await w.host.startGame();
      var maxDead = 0;
      final ticks = await w.playToEnd(maxTicks: 8000, onTick: (r) {
        final dead = w.server.membersOf(w.code).values.where((m) => !m.alive).length;
        if (dead > maxDead) maxDead = dead;
      });
      expect(ticks, lessThan(8000), reason: 'partida $g (n=$n) atascada en ${w.room.phase.name}');
      final r = w.room;
      expect(r.winner, isNotNull);
      expect(VictoryChecker.check(w.host.state!), r.winner, reason: 'partida $g');
      expect(w.server.actionCount(w.code), 0);
      expect(w.server.voteCount(w.code), 0);
      await w.dispose();
    }
  });
}
