import 'dart:math';

import 'package:asesino_core/asesino_core.dart';
import 'package:test/test.dart';

/// Construye un estado de noche con los roles indicados (uid = nombre).
GameState night(
  Map<String, RoleId> roles, {
  GameConfig config = const GameConfig(cupid: true, blocker: true),
  int round = 2,
  List<String> lovers = const [],
  Map<String, String> lastProtected = const {},
}) =>
    GameState(
      config: config,
      phase: Phase.night,
      round: round,
      players: [for (final e in roles.entries) PlayerState(uid: e.key, name: e.key, role: e.value)],
      lovers: lovers,
      lastProtected: lastProtected,
    );

NightAction act(String uid, RoleId role, List<String> targets, {int round = 2}) =>
    NightAction(uid: uid, round: round, role: role, targets: targets);

final base = {
  'ana': RoleId.assassin,
  'bea': RoleId.police,
  'carl': RoleId.doctor,
  'dani': RoleId.civilian,
  'eva': RoleId.civilian,
  'fer': RoleId.blocker,
  'gus': RoleId.cupid,
};

void main() {
  group('GameConfig', () {
    test('los presets son válidos para 5..20 jugadores y cuadran con el total', () {
      for (var n = 5; n <= 20; n++) {
        final c = GameConfig.recommended(n);
        expect(c.validate(n), isEmpty, reason: 'n=$n');
        expect(RoleAssigner.roleBag(c, n), hasLength(n));
      }
    });

    test('presets según la tabla del documento', () {
      expect(GameConfig.recommended(6).assassins, 1);
      expect(GameConfig.recommended(6).cupid, false);
      expect(GameConfig.recommended(9).assassins, 2);
      expect(GameConfig.recommended(9).cupid, true);
      expect(GameConfig.recommended(11).assassins, 2);
      expect(GameConfig.recommended(14).assassins, 3);
      expect(GameConfig.recommended(20).assassins, 4);
    });

    test('rechaza configuraciones imposibles', () {
      expect(const GameConfig().validate(4), isNotEmpty); // pocos
      expect(const GameConfig().validate(21), isNotEmpty); // muchos
      expect(const GameConfig(assassins: 0).validate(8), isNotEmpty);
      expect(const GameConfig(assassins: 4).validate(8), isNotEmpty); // 4 de 8
      expect(const GameConfig(assassins: 1, police: 5, doctors: 5).validate(8), isNotEmpty);
      expect(const GameConfig(nightStepSeconds: 1).validate(8), isNotEmpty);
      expect(
        const GameConfig(nightOrder: [RoleId.assassin]).validate(8),
        isNotEmpty,
      ); // falta policía y médico
      expect(const GameConfig(cupidTeam: Team.assassins).validate(8), isNotEmpty);
    });

    test('serialización ida y vuelta', () {
      const c = GameConfig(
        assassins: 3,
        doctorSelfProtect: false,
        tieRule: TieRule.revote,
        secretVotes: false,
        blockerTeam: Team.assassins,
        loversSpecialWin: true,
      );
      final c2 = GameConfig.fromMap(c.toMap());
      expect(c2.toMap(), c.toMap());
    });

    test('Cupido sólo actúa la primera noche', () {
      const c = GameConfig(cupid: true);
      expect(c.nightSteps(1), contains(RoleId.cupid));
      expect(c.nightSteps(2), isNot(contains(RoleId.cupid)));
    });
  });

  group('RoleAssigner', () {
    test('reparte exactamente los roles configurados', () {
      final uids = [for (var i = 0; i < 12; i++) 'u$i'];
      final cfg = GameConfig.recommended(12);
      final m = RoleAssigner.assign(uids, cfg, Random(1));
      expect(m.length, 12);
      int count(RoleId r) => m.values.where((x) => x == r).length;
      expect(count(RoleId.assassin), 2);
      expect(count(RoleId.police), 1);
      expect(count(RoleId.doctor), 1);
      expect(count(RoleId.cupid), 1);
      expect(count(RoleId.blocker), 1);
      expect(count(RoleId.civilian), 6);
    });

    test('es determinista con la misma semilla e independiente del orden', () {
      final uids = [for (var i = 0; i < 9; i++) 'u$i'];
      final cfg = GameConfig.recommended(9);
      final a = RoleAssigner.assign(uids, cfg, Random(7));
      final b = RoleAssigner.assign(uids.reversed.toList(), cfg, Random(7));
      expect(a, b);
      final c = RoleAssigner.assign(uids, cfg, Random(8));
      expect(c == a, false);
    });

    test('lanza con configuración inválida', () {
      expect(() => RoleAssigner.assign(['a', 'b'], const GameConfig(), Random(1)),
          throwsArgumentError);
    });
  });

  group('ActionValidator', () {
    final s = night(base);
    test('acepta acciones legales', () {
      expect(ActionValidator.validate(s, act('ana', RoleId.assassin, ['dani'])), isNull);
      expect(ActionValidator.validate(s, act('bea', RoleId.police, ['ana'])), isNull);
      expect(ActionValidator.validate(s, act('carl', RoleId.doctor, ['carl'])), isNull);
      expect(ActionValidator.validate(s, act('ana', RoleId.assassin, [])), isNull); // pasar
    });
    test('rechaza acciones ilegales', () {
      expect(ActionValidator.validate(s, act('ana', RoleId.assassin, ['ana'])), isNotNull);
      expect(ActionValidator.validate(s, act('bea', RoleId.police, ['bea'])), isNotNull);
      expect(ActionValidator.validate(s, act('dani', RoleId.assassin, ['eva'])), isNotNull); // rol
      expect(ActionValidator.validate(s, act('dani', RoleId.civilian, ['eva'])), isNotNull);
      expect(ActionValidator.validate(s, act('ana', RoleId.assassin, ['zzz'])), isNotNull);
      expect(ActionValidator.validate(s, act('ana', RoleId.assassin, ['dani'], round: 9)), isNotNull);
      expect(ActionValidator.validate(s, act('ana', RoleId.assassin, ['dani', 'eva'])), isNotNull);
    });
    test('un asesino no puede atacar a su equipo', () {
      final two = night({...base, 'hugo': RoleId.assassin});
      expect(ActionValidator.validate(two, act('ana', RoleId.assassin, ['hugo'])), isNotNull);
    });
    test('un muerto no puede actuar ni ser objetivo', () {
      final dead = s.copyWith(players: [
        for (final p in s.players) p.uid == 'bea' ? p.kill(DeathCause.assassin, 1) : p
      ]);
      expect(ActionValidator.validate(dead, act('bea', RoleId.police, ['ana'])), isNotNull);
      expect(ActionValidator.validate(dead, act('ana', RoleId.assassin, ['bea'])), isNotNull);
    });
    test('médico: autoprotección y repetición configurables', () {
      final noSelf = night(base, config: const GameConfig(doctorSelfProtect: false));
      expect(ActionValidator.validate(noSelf, act('carl', RoleId.doctor, ['carl'])), isNotNull);
      final rep = night(base, lastProtected: {'carl': 'dani'});
      expect(ActionValidator.validate(rep, act('carl', RoleId.doctor, ['dani'])), isNotNull);
      final repOk = night(base,
          config: const GameConfig(doctorRepeatProtect: true), lastProtected: {'carl': 'dani'});
      expect(ActionValidator.validate(repOk, act('carl', RoleId.doctor, ['dani'])), isNull);
    });
    test('Cupido sólo la primera noche y una vez', () {
      final r1 = night(base, round: 1);
      expect(ActionValidator.validate(r1, act('gus', RoleId.cupid, ['ana', 'bea'], round: 1)), isNull);
      expect(ActionValidator.validate(s, act('gus', RoleId.cupid, ['ana', 'bea'])), isNotNull);
      expect(ActionValidator.validate(r1, act('gus', RoleId.cupid, ['ana', 'ana'], round: 1)), isNotNull);
      final noSelf = night(base, round: 1, config: const GameConfig(cupid: true, cupidSelfPick: false));
      expect(ActionValidator.validate(noSelf, act('gus', RoleId.cupid, ['gus', 'ana'], round: 1)), isNotNull);
    });
    test('validTargets respeta las reglas', () {
      final t = ActionValidator.validTargets(night(base, round: 2), 'ana');
      expect(t, isNot(contains('ana')));
      expect(t, contains('dani'));
    });
  });

  group('NightResolver', () {
    NightOutcome run(GameState s, List<NightAction> a, {int seed = 1}) =>
        NightResolver.resolve(s, a, Random(seed));

    test('el asesino mata a su víctima', () {
      final o = run(night(base), [act('ana', RoleId.assassin, ['dani'])]);
      expect(o.deaths.map((d) => d.uid), ['dani']);
      expect(o.state.player('dani')!.alive, false);
      expect(o.state.player('dani')!.deathCause, DeathCause.assassin);
    });

    test('sin acciones asesinas no muere nadie', () {
      expect(run(night(base), []).deaths, isEmpty);
      expect(run(night(base), [act('ana', RoleId.assassin, [])]).deaths, isEmpty);
    });

    test('el médico salva a la víctima', () {
      final o = run(night(base), [
        act('ana', RoleId.assassin, ['dani']),
        act('carl', RoleId.doctor, ['dani']),
      ]);
      expect(o.deaths, isEmpty);
      expect(o.saved, 'dani');
    });

    test('proteger a otro no salva a la víctima', () {
      final o = run(night(base), [
        act('ana', RoleId.assassin, ['dani']),
        act('carl', RoleId.doctor, ['eva']),
      ]);
      expect(o.deaths.map((d) => d.uid), ['dani']);
    });

    test('La Puta bloquea al médico: la protección falla', () {
      final o = run(night(base), [
        act('fer', RoleId.blocker, ['carl']),
        act('ana', RoleId.assassin, ['dani']),
        act('carl', RoleId.doctor, ['dani']),
      ]);
      expect(o.deaths.map((d) => d.uid), ['dani']);
    });

    test('La Puta bloquea al asesino: no hay muerte', () {
      final o = run(night(base), [
        act('fer', RoleId.blocker, ['ana']),
        act('ana', RoleId.assassin, ['dani']),
      ]);
      expect(o.deaths, isEmpty);
    });

    test('bloquear a un asesino no anula los votos de otros asesinos', () {
      final s = night({...base, 'hugo': RoleId.assassin});
      final o = run(s, [
        act('fer', RoleId.blocker, ['ana']),
        act('ana', RoleId.assassin, ['dani']),
        act('hugo', RoleId.assassin, ['eva']),
      ]);
      expect(o.deaths.map((d) => d.uid), ['eva']);
    });

    test('La Puta no puede bloquear roles fuera de la lista configurable', () {
      final s = night(base, config: const GameConfig(cupid: true, blocker: true, blockable: [RoleId.police]));
      final o = run(s, [
        act('fer', RoleId.blocker, ['carl']),
        act('ana', RoleId.assassin, ['dani']),
        act('carl', RoleId.doctor, ['dani']),
      ]);
      expect(o.deaths, isEmpty); // el médico no estaba bloqueado
    });

    test('policía detecta asesinos y no asesinos', () {
      final o = run(night(base), [act('bea', RoleId.police, ['ana'])]);
      expect(o.investigations.single.isAssassin, true);
      final o2 = run(night(base), [act('bea', RoleId.police, ['dani'])]);
      expect(o2.investigations.single.isAssassin, false);
      expect(o2.state.investigations, hasLength(1));
    });

    test('policía bloqueado no obtiene resultado', () {
      final o = run(night(base), [
        act('fer', RoleId.blocker, ['bea']),
        act('bea', RoleId.police, ['ana']),
      ]);
      expect(o.investigations.single.blocked, true);
      expect(o.investigations.single.isAssassin, false);
    });

    test('Cupido crea enamorados; si uno muere el otro también', () {
      final r1 = night(base, round: 1);
      final o = run(r1, [
        act('gus', RoleId.cupid, ['dani', 'eva'], round: 1),
        act('ana', RoleId.assassin, ['dani'], round: 1),
      ]);
      expect(o.state.lovers, ['dani', 'eva']);
      expect(o.deaths.map((d) => d.uid).toSet(), {'dani', 'eva'});
      expect(o.deaths.firstWhere((d) => d.uid == 'eva').cause, DeathCause.heartbreak);
    });

    test('Cupido bloqueado no crea enamorados si es bloqueable por configuración', () {
      final r1 = night(base,
          round: 1,
          config: const GameConfig(cupid: true, blocker: true, blockable: [RoleId.cupid]));
      final o = run(r1, [
        act('fer', RoleId.blocker, ['gus'], round: 1),
        act('gus', RoleId.cupid, ['dani', 'eva'], round: 1),
      ]);
      expect(o.state.lovers, isEmpty);
    });

    test('por defecto Cupido no es bloqueable', () {
      final r1 = night(base, round: 1);
      final o = run(r1, [
        act('fer', RoleId.blocker, ['gus'], round: 1),
        act('gus', RoleId.cupid, ['dani', 'eva'], round: 1),
      ]);
      expect(o.state.lovers, ['dani', 'eva']);
    });

    test('los enamorados existentes mueren en cadena', () {
      final s = night(base, lovers: ['dani', 'bea']);
      final o = run(s, [act('ana', RoleId.assassin, ['bea'])]);
      expect(o.deaths.map((d) => d.uid).toSet(), {'bea', 'dani'});
    });

    test('empate de asesinos: determinista con la misma semilla', () {
      final s = night({...base, 'hugo': RoleId.assassin});
      final acts = [
        act('ana', RoleId.assassin, ['dani']),
        act('hugo', RoleId.assassin, ['eva']),
      ];
      final a = run(s, acts, seed: 5).deaths.single.uid;
      final b = run(s, acts, seed: 5).deaths.single.uid;
      expect(a, b);
      final seen = {for (var seed = 0; seed < 30; seed++) run(s, acts, seed: seed).deaths.single.uid};
      expect(seen, {'dani', 'eva'});
    });

    test('mayoría de asesinos gana al empate', () {
      final s = night({...base, 'hugo': RoleId.assassin, 'ivan': RoleId.assassin});
      final o = run(s, [
        act('ana', RoleId.assassin, ['dani']),
        act('hugo', RoleId.assassin, ['dani']),
        act('ivan', RoleId.assassin, ['eva']),
      ]);
      expect(o.deaths.single.uid, 'dani');
    });

    test('rechaza acciones inválidas y duplicadas sin afectar al resto', () {
      final o = run(night(base), [
        act('ana', RoleId.assassin, ['dani']),
        act('ana', RoleId.assassin, ['eva']),
        act('dani', RoleId.assassin, ['eva']),
        act('bea', RoleId.police, ['bea']),
      ]);
      expect(o.rejected.length, 3);
      expect(o.deaths.single.uid, 'dani');
    });

    test('es pura: no modifica el estado de entrada', () {
      final s = night(base);
      run(s, [act('ana', RoleId.assassin, ['dani'])]);
      expect(s.player('dani')!.alive, true);
    });

    test('guarda el último protegido del médico', () {
      final o = run(night(base), [act('carl', RoleId.doctor, ['dani'])]);
      expect(o.state.lastProtected['carl'], 'dani');
    });
  });

  group('VoteResolver', () {
    GameState day([GameConfig c = const GameConfig()]) => GameState(
          config: c,
          phase: Phase.voting,
          round: 1,
          players: [
            for (final e in base.entries) PlayerState(uid: e.key, name: e.key, role: e.value)
          ],
        );
    VoteOutcome vote(GameState s, Map<String, String> v,
            {List<String>? candidates, bool isRevote = false, int seed = 1}) =>
        VoteResolver.resolve(s, v, Random(seed), candidates: candidates, isRevote: isRevote);

    test('expulsa al más votado', () {
      final o = vote(day(), {'ana': 'dani', 'bea': 'dani', 'carl': 'ana'});
      expect(o.eliminated, 'dani');
      expect(o.tally, {'dani': 2, 'ana': 1});
      expect(o.state.player('dani')!.alive, false);
      expect(o.state.player('dani')!.deathCause, DeathCause.vote);
    });

    test('empate sin eliminación', () {
      final o = vote(day(), {'ana': 'dani', 'bea': 'ana'});
      expect(o.eliminated, isNull);
      expect(o.tied, ['ana', 'dani']);
      expect(o.needsRevote, false);
    });

    test('empate con repetición, y en la repetición ya no se repite', () {
      final c = const GameConfig(tieRule: TieRule.revote);
      final o = vote(day(c), {'ana': 'dani', 'bea': 'ana'});
      expect(o.needsRevote, true);
      expect(o.tied, ['ana', 'dani']);
      final o2 = vote(day(c), {'carl': 'dani', 'eva': 'ana'}, candidates: o.tied, isRevote: true);
      expect(o2.needsRevote, false);
      expect(o2.eliminated, isNull);
    });

    test('empate al azar elige a uno de los empatados', () {
      final c = const GameConfig(tieRule: TieRule.random);
      final seen = {
        for (var s = 0; s < 30; s++)
          vote(day(c), {'ana': 'dani', 'bea': 'ana'}, seed: s).eliminated
      };
      expect(seen, {'dani', 'ana'});
    });

    test('abstención cuenta aparte y no elimina', () {
      final o = vote(day(), {'ana': kAbstain, 'bea': kAbstain});
      expect(o.eliminated, isNull);
      expect(o.abstentions, 2);
    });

    test('abstención deshabilitada: el voto se ignora', () {
      final o = vote(day(const GameConfig(allowAbstain: false)), {'ana': kAbstain, 'bea': 'dani'});
      expect(o.abstentions, 0);
      expect(o.eliminated, 'dani');
    });

    test('ignora votos inválidos (a uno mismo, a muertos, de muertos, a desconocidos)', () {
      final s = day().copyWith(players: [
        for (final p in day().players) p.uid == 'eva' ? p.kill(DeathCause.assassin, 1) : p
      ]);
      final o = vote(s, {'ana': 'ana', 'bea': 'eva', 'eva': 'dani', 'carl': 'zzz', 'dani': 'carl'});
      expect(o.validVotes, {'dani': 'carl'});
      expect(o.eliminated, 'carl');
    });

    test('expulsar a un enamorado mata a su pareja', () {
      final s = day().copyWith(lovers: ['dani', 'eva']);
      final o = vote(s, {'ana': 'dani', 'bea': 'dani'});
      expect(o.deaths.map((d) => d.uid).toSet(), {'dani', 'eva'});
    });

    test('duelo sin salida (2 vivos, ninguno puede matar): el empate se resuelve al azar', () {
      const cfg = GameConfig(blocker: true, blockerTeam: Team.assassins, assassinsNeedStrictMajority: true);
      for (final tie in TieRule.values) {
        final s = GameState(
          config: cfg.copyWith(tieRule: tie),
          phase: Phase.voting,
          round: 9,
          players: const [
            PlayerState(uid: 'p', name: 'p', role: RoleId.blocker),
            PlayerState(uid: 'c', name: 'c', role: RoleId.civilian),
          ],
        );
        final tied = VoteResolver.resolve(s, {'p': 'c', 'c': 'p'}, Random(1));
        expect(tied.eliminated, isNotNull, reason: tie.name);
        expect(tied.needsRevote, false);
        final abst = VoteResolver.resolve(s, {'p': kAbstain, 'c': kAbstain}, Random(2));
        expect(abst.eliminated, isNotNull, reason: 'abstención ${tie.name}');
        // Se eliminan ambos resultados posibles según la semilla.
        final seen = {
          for (var seed = 0; seed < 30; seed++)
            VoteResolver.resolve(s, {'p': 'c', 'c': 'p'}, Random(seed)).eliminated
        };
        expect(seen, {'p', 'c'});
        // Si uno vota y el otro se abstiene, manda el voto (sin azar).
        final one = VoteResolver.resolve(s, {'p': 'c', 'c': kAbstain}, Random(3));
        expect(one.eliminated, 'c');
      }
    });

    test('duelo normal (queda un asesino que sí mata): el empate no elimina a nadie', () {
      const s = GameState(
        config: GameConfig(),
        phase: Phase.voting,
        round: 9,
        players: [
          PlayerState(uid: 'a', name: 'a', role: RoleId.assassin),
          PlayerState(uid: 'c', name: 'c', role: RoleId.civilian),
        ],
      );
      final o = VoteResolver.resolve(s, {'a': 'c', 'c': 'a'}, Random(1));
      expect(o.eliminated, isNull);
    });

    test('sin votos no hay eliminación', () {
      expect(vote(day(), {}).eliminated, isNull);
    });
  });

  group('VictoryChecker', () {
    GameState st(Map<String, RoleId> roles, {GameConfig c = const GameConfig(), List<String> lovers = const []}) =>
        night(roles, config: c, lovers: lovers);

    test('gana el pueblo sin asesinos vivos', () {
      expect(VictoryChecker.check(st({'a': RoleId.civilian, 'b': RoleId.police})), Winner.town);
    });
    test('ganan los asesinos con paridad', () {
      expect(VictoryChecker.check(st({'a': RoleId.assassin, 'b': RoleId.civilian})), Winner.assassins);
    });
    test('la partida sigue si el pueblo supera a los asesinos', () {
      expect(
          VictoryChecker.check(st({'a': RoleId.assassin, 'b': RoleId.civilian, 'c': RoleId.police})),
          isNull);
    });
    test('mayoría estricta exige superar, no igualar', () {
      const strict = GameConfig(assassinsNeedStrictMajority: true);
      expect(VictoryChecker.check(st({'a': RoleId.assassin, 'b': RoleId.civilian}, c: strict)), isNull);
      expect(
          VictoryChecker.check(
              st({'a': RoleId.assassin, 'b': RoleId.assassin, 'c': RoleId.civilian}, c: strict)),
          Winner.assassins);
    });
    test('enamorados ganan solos si son de equipos distintos y es opción activa', () {
      const c = GameConfig(loversSpecialWin: true);
      final s = st({'a': RoleId.assassin, 'b': RoleId.civilian}, c: c, lovers: ['a', 'b']);
      expect(VictoryChecker.check(s), Winner.lovers);
      expect(VictoryChecker.check(st({'a': RoleId.assassin, 'b': RoleId.civilian}, lovers: ['a', 'b'])),
          Winner.assassins);
    });
    test('Cupido neutral cuenta como no asesino para la paridad', () {
      const c = GameConfig(cupid: true, cupidTeam: Team.neutral);
      final s = st({'a': RoleId.assassin, 'b': RoleId.cupid, 'c': RoleId.civilian}, c: c);
      expect(s.teamOf('b'), Team.neutral);
      expect(VictoryChecker.check(s), isNull);
    });
    test('La Puta en el bando asesino cuenta como asesina', () {
      const c = GameConfig(blocker: true, blockerTeam: Team.assassins);
      final s = st({'a': RoleId.assassin, 'f': RoleId.blocker, 'c': RoleId.civilian}, c: c);
      expect(VictoryChecker.check(s), Winner.assassins);
    });
  });

  group('PhaseMachine', () {
    test('sólo permite las transiciones del flujo definido', () {
      expect(PhaseMachine.canTransition(Phase.lobby, Phase.roleReveal), true);
      expect(PhaseMachine.canTransition(Phase.night, Phase.dawn), true);
      expect(PhaseMachine.canTransition(Phase.night, Phase.voting), false);
      expect(PhaseMachine.canTransition(Phase.discussion, Phase.night), false);
      expect(PhaseMachine.canTransition(Phase.voteResult, Phase.voting), true);
      expect(PhaseMachine.canTransition(Phase.voting, Phase.finished), true); // abortar
    });
    test('tras la comprobación de victoria', () {
      expect(PhaseMachine.afterVictoryCheck(hasWinner: true, fromDawn: true), Phase.finished);
      expect(PhaseMachine.afterVictoryCheck(hasWinner: false, fromDawn: true), Phase.discussion);
      expect(PhaseMachine.afterVictoryCheck(hasWinner: false, fromDawn: false), Phase.nextRound);
    });
  });

  group('Roles forzados (tutorial)', () {
    final uids = [for (var i = 0; i < 7; i++) 'u$i'];
    final cfg = GameConfig.recommended(7);

    test('el jugador forzado recibe su rol y el resto cuadra con la bolsa', () {
      for (var seed = 0; seed < 20; seed++) {
        final m = RoleAssigner.assign(uids, cfg, Random(seed), forced: {'u3': RoleId.police});
        expect(m['u3'], RoleId.police);
        int count(RoleId r) => m.values.where((x) => x == r).length;
        expect(count(RoleId.police), 1);
        expect(count(RoleId.assassin), 1);
        expect(count(RoleId.doctor), 1);
        expect(count(RoleId.civilian), 4);
      }
    });

    test('es determinista y el resto se baraja', () {
      final a = RoleAssigner.assign(uids, cfg, Random(5), forced: {'u0': RoleId.police});
      final b = RoleAssigner.assign(uids, cfg, Random(5), forced: {'u0': RoleId.police});
      expect(a, b);
      final seen = {
        for (var seed = 0; seed < 30; seed++)
          RoleAssigner.assign(uids, cfg, Random(seed), forced: {'u0': RoleId.police})['u1']
      };
      expect(seen.length, greaterThan(1));
    });

    test('rechaza roles que no están en la configuración o jugadores desconocidos', () {
      expect(() => RoleAssigner.assign(uids, cfg, Random(1), forced: {'u0': RoleId.cupid}),
          throwsArgumentError);
      expect(() => RoleAssigner.assign(uids, cfg, Random(1), forced: {'zzz': RoleId.police}),
          throwsArgumentError);
      expect(
          () => RoleAssigner.assign(uids, cfg, Random(1),
              forced: {'u0': RoleId.police, 'u1': RoleId.police}),
          throwsArgumentError);
    });
  });

  group('Chat: reglas', () {
    test('sólo se escribe en fases abiertas; los eliminados sólo en lobby y final', () {
      expect(ChatMessage.canWrite(Phase.night, alive: true), false);
      expect(ChatMessage.canWrite(Phase.roleReveal, alive: true), false);
      expect(ChatMessage.canWrite(Phase.discussion, alive: true), true);
      expect(ChatMessage.canWrite(Phase.discussion, alive: false), false);
      expect(ChatMessage.canWrite(Phase.voting, alive: true), true);
      expect(ChatMessage.canWrite(Phase.lobby, alive: false), true);
      expect(ChatMessage.canWrite(Phase.finished, alive: false), true);
    });
    test('validación del texto', () {
      expect(ChatMessage.validateText('   '), isNotNull);
      expect(ChatMessage.validateText('hola'), isNull);
      expect(ChatMessage.validateText('x' * 201), isNotNull);
      expect(ChatMessage.validateText('x' * 200), isNull);
    });
  });

  group('Serialización', () {
    test('GameState ida y vuelta conserva todo', () {
      final s = night(base, lovers: ['dani', 'eva'], lastProtected: {'carl': 'dani'}).copyWith(
        investigations: [
          const Investigation(police: 'bea', round: 1, target: 'ana', isAssassin: true, blocked: false)
        ],
      );
      final s2 = GameState.fromMap(s.toMap());
      expect(s2.toMap(), s.toMap());
    });
    test('PrivateDoc: sólo el equipo asesino conoce a sus compañeros', () {
      final s = night({...base, 'hugo': RoleId.assassin}, lovers: ['dani', 'eva']);
      final ana = PrivateDoc.forPlayer(s, 'ana');
      expect(ana.teammates, ['hugo']);
      expect(PrivateDoc.forPlayer(s, 'bea').teammates, isEmpty);
      expect(PrivateDoc.forPlayer(s, 'dani').partner, 'eva');
      expect(PrivateDoc.forPlayer(s, 'bea').partner, isNull);
    });
    test('RoomCodes', () {
      final r = Random(3);
      for (var i = 0; i < 50; i++) {
        expect(RoomCodes.isValid(RoomCodes.generate(r)), true);
      }
      expect(RoomCodes.normalize(' ab-c d2 '), 'ABCD2');
      expect(RoomCodes.isValid('ABC0EF'), false);
    });
    test('narrador', () {
      expect(Narrator.dawn([]).text, contains('nadie'));
      expect(Narrator.dawn(['Ana']).text, contains('Ana'));
      expect(Narrator.dawn(['Ana', 'Bea', 'Carl']).text, contains('Ana, Bea y Carl'));
      expect(Narrator.victory(Winner.town).cue, Cue.victory);
    });
  });
}
