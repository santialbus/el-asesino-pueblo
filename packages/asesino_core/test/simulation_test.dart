import 'dart:math';

import 'package:asesino_core/asesino_core.dart';
import 'package:asesino_core/asesino_core_testing.dart';
import 'package:test/test.dart';

import 'support/world.dart';

Future<Object?> errorOf(Future<void> Function() f) async {
  try {
    await f();
  } catch (e) {
    return e;
  }
  return null;
}

Future<Object?> streamError(Stream<Object?> s) async {
  try {
    await s.first;
  } catch (e) {
    return e;
  }
  return null;
}

/// Comprobaciones comunes de una partida terminada.
void expectFinishedCleanly(World w, int players) {
  final r = w.room;
  expect(r.phase, Phase.finished);
  expect(r.winner, isNotNull);
  expect(r.finalRoles.length, players);
  expect(w.server.actionCount(w.code), 0, reason: 'acciones sin limpiar');
  expect(w.server.voteCount(w.code), 0, reason: 'votos sin limpiar');
  // El ganador publicado coincide con las reglas aplicadas al estado final.
  expect(VictoryChecker.check(w.host.state!), r.winner);
  // Roles revelados a todos al final.
  for (final m in w.server.membersOf(w.code).values) {
    if (!m.isNarrator) expect(m.revealedRole, isNotNull);
  }
}

void main() {
  group('Partidas completas con narrador automático', () {
    for (final n in [5, 8, 12, 20]) {
      for (final seed in [1, 2, 3]) {
        test('$n jugadores, semilla $seed', () async {
          final w = await World.create(n, seed: seed);
          await w.host.startGame();
          await settle();
          expect(w.room.phase, Phase.roleReveal);
          final ticks = await w.playToEnd();
          expect(ticks, lessThan(6000), reason: 'la partida no terminó');
          expectFinishedCleanly(w, n);
          await w.dispose();
        });
      }
    }

    test('con todas las reglas alternativas (revote, voto público, mayoría estricta, enamorados)', () async {
      final cfg = GameConfig.recommended(12).copyWith(
        tieRule: TieRule.revote,
        secretVotes: false,
        assassinsNeedStrictMajority: true,
        loversSpecialWin: true,
        cupidTeam: Team.neutral,
        blockerTeam: Team.assassins,
        doctorRepeatProtect: true,
        announceSaves: true,
        revealRoleOnDeath: false,
      );
      for (final seed in [11, 12, 13, 14]) {
        final w = await World.create(12, config: cfg, seed: seed);
        await w.host.startGame();
        await w.playToEnd();
        expectFinishedCleanly(w, 12);
        await w.dispose();
      }
    });

    test('tieRule random y sin abstención', () async {
      final cfg = GameConfig.recommended(9).copyWith(tieRule: TieRule.random, allowAbstain: false);
      final w = await World.create(9, config: cfg, seed: 21);
      await w.host.startGame();
      await w.playToEnd();
      expectFinishedCleanly(w, 9);
      await w.dispose();
    });
  });

  group('Narrador humano', () {
    test('el narrador no juega y modera con advance()', () async {
      final w = await World.create(6,
          narrator: NarratorMode.human, hostPlays: false, seed: 4);
      expect(w.server.membersOf(w.code)['u0']!.isNarrator, true);
      await w.host.startGame();
      await settle();
      final st = w.host.state!;
      expect(st.players.length, 6);
      expect(st.player('u0'), isNull);
      // Sin avance manual no hay temporizador automático.
      w.clock.advance(const Duration(hours: 1));
      await w.host.tick();
      await settle();
      expect(w.room.phase, Phase.roleReveal);
      await w.playToEnd();
      expectFinishedCleanly(w, 6);
      await w.dispose();
    });

    test('el moderador puede participar si se configura', () async {
      final w = await World.create(7,
          narrator: NarratorMode.human, hostPlays: true, seed: 5);
      await w.host.startGame();
      expect(w.host.state!.player('u0'), isNotNull);
      await w.playToEnd();
      expectFinishedCleanly(w, 7);
      await w.dispose();
    });
  });

  group('Privacidad (reglas emuladas)', () {
    test('un jugador no puede leer roles, acciones, votos ni estado del anfitrión', () async {
      final w = await World.create(8, seed: 6);
      await w.host.startGame();
      await settle();
      final other = w.backends[3];
      expect(await streamError(other.watchPrivate(w.code, 'u1')), isA<PermissionDeniedException>());
      expect(await streamError(other.watchActions(w.code, 1)), isA<PermissionDeniedException>());
      expect(await streamError(other.watchVotes(w.code, 1)), isA<PermissionDeniedException>());
      expect(await streamError(other.watchPresence(w.code)), isA<PermissionDeniedException>());
      expect(await errorOf(() => other.readHostState(w.code)), isA<PermissionDeniedException>());
      // Su propio documento sí.
      expect(await streamError(other.watchPrivate(w.code, 'u3')), isNull);
      await w.dispose();
    });

    test('durante la partida la sala pública no contiene roles de vivos', () async {
      final w = await World.create(10, seed: 7);
      await w.host.startGame();
      var leaks = 0;
      await w.playToEnd(onTick: (r) {
        if (r.phase != Phase.finished && r.finalRoles.isNotEmpty) leaks++;
        for (final m in w.server.membersOf(w.code).values) {
          if (m.alive && m.revealedRole != null && r.phase != Phase.finished) leaks++;
        }
      });
      expect(leaks, 0);
      await w.dispose();
    });

    test('cada jugador recibe sólo su rol; los asesinos conocen a sus compañeros', () async {
      final w = await World.create(12, seed: 8);
      await w.host.startGame();
      await settle();
      final st = w.host.state!;
      final privates = w.server.privatesOf(w.code);
      for (final p in st.players) {
        expect(privates[p.uid]!.role, p.role);
        if (p.role != RoleId.assassin) expect(privates[p.uid]!.teammates, isEmpty);
      }
      final assassins = st.players.where((p) => p.role == RoleId.assassin).map((p) => p.uid).toList();
      for (final a in assassins) {
        expect(privates[a]!.teammates.toSet(), assassins.where((x) => x != a).toSet());
      }
      await w.dispose();
    });

    test('voto secreto: el resultado público no incluye quién votó a quién', () async {
      final w = await World.create(8, seed: 9, config: GameConfig.recommended(8).copyWith(secretVotes: true, cupid: false, blocker: false));
      await w.host.startGame();
      var seenResult = false;
      var leaked = false;
      await w.playToEnd(onTick: (r) {
        final vr = r.voteResult;
        if (vr != null) {
          seenResult = true;
          if (vr.votes.isNotEmpty) leaked = true;
        }
      });
      expect(seenResult, true);
      expect(leaked, false);
      await w.dispose();
    });

    test('voto público: el resultado incluye los votos', () async {
      final w = await World.create(8, seed: 9, config: GameConfig.recommended(8).copyWith(secretVotes: false, cupid: false, blocker: false));
      await w.host.startGame();
      var withVotes = false;
      await w.playToEnd(onTick: (r) {
        if (r.voteResult != null && r.voteResult!.votes.isNotEmpty) withVotes = true;
      });
      expect(withVotes, true);
      await w.dispose();
    });
  });

  group('Acciones y votos inválidos', () {
    test('una acción duplicada es rechazada', () async {
      final w = await World.create(8, seed: 10);
      await w.host.startGame();
      // Avanza hasta la noche y hasta el turno de los asesinos.
      var guard = 0;
      while (w.room.nightStep != RoleId.assassin && guard++ < 200) {
        w.clock.advance(const Duration(seconds: 1));
        await w.host.tick();
        await settle();
      }
      expect(w.room.nightStep, RoleId.assassin);
      final assassin = w.host.state!.players.firstWhere((p) => p.role == RoleId.assassin);
      final target = w.host.state!.players.firstWhere((p) => p.role == RoleId.civilian);
      final b = w.backends[int.parse(assassin.uid.substring(1))];
      final room = w.room;
      final pa = PlayerActions(b, w.code);
      await pa.submitNight(room, RoleId.assassin, [target.uid]);
      final err = await errorOf(() => pa.submitNight(room, RoleId.assassin, [target.uid]));
      expect(err, isA<PermissionDeniedException>());
      await w.dispose();
    });

    test('no se puede actuar fuera de turno ni con un rol ajeno', () async {
      final w = await World.create(8, seed: 10);
      await w.host.startGame();
      var guard = 0;
      while (w.room.phase != Phase.night && guard++ < 100) {
        w.clock.advance(const Duration(seconds: 1));
        await w.host.tick();
        await settle();
      }
      final room = w.room;
      final civ = w.host.state!.players.firstWhere((p) => p.role == RoleId.civilian);
      final b = w.backends[int.parse(civ.uid.substring(1))];
      final e1 = await errorOf(() => PlayerActions(b, w.code).submitNight(room, RoleId.assassin, ['u1']));
      expect(e1, isA<PermissionDeniedException>());
      await w.dispose();
    });

    test('el anfitrión descarta un voto inválido (a sí mismo) aunque llegue a Firestore', () async {
      final w = await World.create(7,
          seed: 12, config: GameConfig.recommended(7).copyWith(cupid: false, blocker: false));
      await w.host.startGame();
      var guard = 0;
      while (w.room.phase != Phase.voting && guard++ < 600) {
        w.clock.advance(const Duration(seconds: 1));
        await w.host.tick();
        await settle();
        if (w.room.phase == Phase.voting) break; // antes de que voten los bots
        for (final b in w.bots) {
          await b.act();
        }
        await settle();
      }
      expect(w.room.phase, Phase.voting);
      final voter = w.host.state!.alive.firstWhere((p) => p.uid != 'u0');
      final b = w.backends[int.parse(voter.uid.substring(1))];
      // La regla emulada sólo comprueba fase/pertenencia; el motor decide la validez.
      await b.submitVote(w.code, VoteDoc(uid: voter.uid, seq: w.room.voteSeq, target: voter.uid));
      await settle();
      expect(w.host.rejectedLog.any((l) => l.contains('voto inválido')), true);
      await w.dispose();
    });

    test('un muerto no puede votar ni actuar', () async {
      final w = await World.create(8, seed: 13);
      await w.host.startGame();
      await w.playToEnd(maxTicks: 6000);
      // Al final todos pueden estar muertos o vivos; comprobamos a un muerto cualquiera.
      final dead = w.server.membersOf(w.code).values.where((m) => !m.alive);
      if (dead.isNotEmpty) {
        final b = w.backends[int.parse(dead.first.uid.substring(1))];
        final err = await errorOf(() => b.submitVote(
            w.code, VoteDoc(uid: b.uid, seq: w.room.voteSeq, target: 'u1')));
        expect(err, isA<PermissionDeniedException>());
      }
      await w.dispose();
    });
  });

  group('Lobby', () {
    test('no se puede iniciar con menos de 5 jugadores', () async {
      final w = await World.create(5, seed: 1);
      await w.backends[4].leaveRoom(w.code, inGame: false);
      await settle();
      expect(w.host.startErrors(), isNotEmpty);
      final err = await errorOf(() => w.host.startGame());
      expect(err, isA<GameStartException>());
      expect(w.room.phase, Phase.lobby);
      await w.dispose();
    });

    test('no se puede entrar a una partida empezada', () async {
      final w = await World.create(6, seed: 1);
      await w.host.startGame();
      final late = w.server.client('late');
      final err = await errorOf(() => late.joinRoom(
          w.code, MemberDoc(uid: 'late', name: 'Tarde', joinedAtMs: w.clock.ms)));
      expect(err, isA<RoomNotJoinableException>());
      await w.dispose();
    });

    test('el anfitrión puede expulsar y cambiar la configuración', () async {
      final w = await World.create(7, seed: 1);
      await w.host.kick('u6');
      await settle();
      expect(w.server.membersOf(w.code).containsKey('u6'), false);
      await w.host.updateLobby(
        name: 'Nueva',
        config: GameConfig.recommended(6).copyWith(assassins: 2),
      );
      expect(w.room.name, 'Nueva');
      expect(w.room.config.assassins, 2);
      await w.dispose();
    });

    test('una sala duplicada se rechaza', () async {
      final w = await World.create(5, seed: 1);
      final b = w.server.client('x');
      final err = await errorOf(() => b.createRoom(
          w.room.copyWith(hostUid: 'x'),
          const MemberDoc(uid: 'x', name: 'X', joinedAtMs: 0)));
      expect(err, isA<RoomExistsException>());
      await w.dispose();
    });

    test('sala inexistente', () async {
      final w = await World.create(5, seed: 1);
      expect(await w.backends[1].getRoom('ZZZZZZ'), isNull);
      await w.dispose();
    });
  });

  group('Abandonos, desconexiones y cambio de anfitrión', () {
    test('un jugador que abandona queda eliminado y la partida continúa', () async {
      final w = await World.create(9, seed: 14);
      await w.host.startGame();
      await settle();
      await w.backends[5].leaveRoom(w.code, inGame: true);
      await settle();
      final p = w.host.state!.player('u5')!;
      expect(p.alive, false);
      expect(p.deathCause, DeathCause.abandon);
      expect(w.server.membersOf(w.code)['u5']!.alive, false);
      await w.playToEnd();
      expectFinishedCleanly(w, 9);
      await w.dispose();
    });

    test('si abandonan todos los asesinos gana el pueblo', () async {
      final w = await World.create(7, seed: 15);
      await w.host.startGame();
      await settle();
      final assassins = w.host.state!.players.where((p) => p.role == RoleId.assassin);
      for (final a in assassins) {
        await w.backends[int.parse(a.uid.substring(1))].leaveRoom(w.code, inGame: true);
      }
      await settle();
      expect(w.room.phase, Phase.finished);
      expect(w.room.winner, Winner.town);
      await w.dispose();
    });

    test('presencia aproximada: sin latidos el miembro pasa a desconectado', () async {
      final w = await World.create(6, seed: 16);
      await settle();
      // Todos latieron una vez.
      for (final b in w.backends) {
        await b.heartbeat(w.code, asHost: b.uid == 'u0');
      }
      await settle();
      w.clock.advance(const Duration(seconds: 31));
      await w.host.tick();
      await settle();
      // Sigue latiendo sólo u1.
      for (var i = 0; i < 6; i++) {
        w.clock.advance(const Duration(seconds: 31));
        await w.backends[1].heartbeat(w.code, asHost: false);
        await settle();
        await w.host.tick();
        await settle();
      }
      final m = w.server.membersOf(w.code);
      expect(m['u1']!.online, true);
      expect(m['u2']!.online, false);
      await w.dispose();
    });

    test('no se puede reclamar el anfitrión mientras sigue latiendo', () async {
      final w = await World.create(6, seed: 17);
      await w.host.startGame();
      w.clock.advance(const Duration(seconds: 20));
      expect(await w.backends[2].claimHost(w.code), false);
      await w.dispose();
    });

    test('caída del anfitrión: otro jugador toma el control y la partida termina', () async {
      for (final seed in [18, 19, 20]) {
        final w = await World.create(10, seed: seed);
        await w.host.startGame();
        // Juega hasta mitad de partida.
        var guard = 0;
        while (w.room.round < 2 && guard++ < 400) {
          await settle();
          for (final b in w.bots) {
            await b.act();
          }
          await settle();
          w.clock.advance(const Duration(seconds: 1));
          await w.host.tick();
        }
        expect(w.room.round, greaterThanOrEqualTo(2));
        final phaseBefore = w.room.phase;
        final roundBefore = w.room.round;
        final stateBefore = w.host.state!.toMap();

        // El anfitrión se cae: deja de latir.
        await w.host.stop();
        w.clock.advance(const Duration(seconds: 60));
        // Otro jugador (vivo, para poder seguir jugando) reclama el control.
        final claimer = w.bots.firstWhere((b) => b.uid != 'u0' && (b.self?.alive ?? false));
        expect(await claimer.backend.claimHost(w.code), true);
        expect(w.room.hostUid, claimer.uid);

        final newHost = HostCoordinator(
          backend: claimer.backend,
          roomId: w.code,
          room: w.room,
          rng: Random(seed),
          now: w.clock.now,
        );
        await newHost.start();
        await settle();
        // Recupera el estado exacto desde hostState.
        expect(newHost.state!.round, roundBefore);
        expect(newHost.state!.phase, phaseBefore);
        expect(newHost.state!.toMap(), stateBefore);

        await w.playToEnd(hostOverride: newHost);
        w.host = newHost;
        expectFinishedCleanly(w, 10);
        await newHost.stop();
        for (final b in w.bots) {
          await b.dispose();
        }
      }
    });

    test('el anfitrión antiguo ya no puede escribir tras ser sustituido', () async {
      final w = await World.create(6, seed: 22);
      await w.host.startGame();
      await settle();
      w.clock.advance(const Duration(seconds: 60));
      expect(await w.backends[1].claimHost(w.code), true);
      await settle();
      final before = w.room.phase;
      await settle();
      // El anfitrión antiguo detecta el relevo y deja de escribir.
      await w.host.advance();
      expect(w.host.lost, true);
      expect(w.room.phase, before);
      expect(w.room.hostUid, 'u1');
      await w.dispose();
    });
  });


  group('Modo local con bots', () {
    test('BotDriver hace jugar a los bots hasta el final de la partida', () async {
      final w = await World.create(8, seed: 31);
      // El "humano" (u0) también la juega un bot: aquí sólo se comprueba el conductor.
      final driver = BotDriver(w.bots, rng: Random(3));
      await w.host.startGame();
      var i = 0;
      for (; i < 6000 && w.room.phase != Phase.finished; i++) {
        await settle();
        await driver.pulse(force: true);
        await settle();
        w.clock.advance(const Duration(seconds: 1));
        await w.host.tick();
      }
      expect(i, lessThan(6000));
      expectFinishedCleanly(w, 8);
      await w.dispose();
    });

    test('un bot muerto o narrador no actúa', () async {
      final w = await World.create(6,
          narrator: NarratorMode.human, hostPlays: false, seed: 32);
      await w.host.startGame();
      await settle();
      final narratorBot = w.bots.firstWhere((b) => b.uid == 'u0');
      await narratorBot.act(); // no debe lanzar ni escribir
      expect(w.server.actionCount(w.code), 0);
      await w.dispose();
    });

    test('RealClock avanza con el tiempo real', () async {
      final c = RealClock();
      final a = c.ms;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.ms, greaterThan(a));
      c.advance(const Duration(hours: 5)); // sin efecto
      expect(c.now().difference(DateTime.now()).inSeconds.abs(), lessThan(2));
    });

    test('una sala con reloj real se crea y arranca con bots', () async {
      final server = InMemoryServer(RealClock());
      final human = server.client('you');
      final code = RoomCodes.generate(Random(1));
      final cfg = GameConfig.recommended(6).copyWith(discussionSeconds: 10, votingSeconds: 10, nightStepSeconds: 5);
      final room = RoomDoc(
        code: code, name: 'Local', hostUid: 'you', narrator: NarratorMode.auto,
        phase: Phase.lobby, round: 0, version: 1, config: cfg, createdAtMs: 0,
      );
      await human.createRoom(room, const MemberDoc(uid: 'you', name: 'Tú', joinedAtMs: 0));
      for (var i = 0; i < 5; i++) {
        await server.client('b$i').joinRoom(code, MemberDoc(uid: 'b$i', name: kBotNames[i], joinedAtMs: i + 1));
      }
      final host = HostCoordinator(backend: human, roomId: code, room: room);
      await host.start();
      await host.startGame();
      await settle();
      expect(server.roomDoc(code)!.phase, Phase.roleReveal);
      expect(host.state!.players.length, 6);
      await host.stop();
    });
  });


  group('Chat de sala', () {
    test('lobby: todos escriben y todos los miembros leen', () async {
      final w = await World.create(5, seed: 41);
      await w.backends[1].sendChat(w.code, '  hola a todos  ');
      await w.backends[2].sendChat(w.code, 'buenas');
      final msgs = await w.backends[3].watchChat(w.code).first;
      expect(msgs.map((m) => m.text).toList(), ['hola a todos', 'buenas']);
      expect(msgs.first.name, 'Jugador 1'); // el nombre sale del miembro, no del cliente
      await w.dispose();
    });

    test('un no miembro no puede leer ni escribir', () async {
      final w = await World.create(5, seed: 41);
      final out = w.server.client('intruso');
      expect(await streamError(out.watchChat(w.code)), isA<PermissionDeniedException>());
      expect(await errorOf(() => out.sendChat(w.code, 'hola')), isA<PermissionDeniedException>());
      await w.dispose();
    });

    test('mensajes vacíos o demasiado largos se rechazan', () async {
      final w = await World.create(5, seed: 41);
      expect(await errorOf(() => w.backends[1].sendChat(w.code, '   ')), isA<PermissionDeniedException>());
      expect(await errorOf(() => w.backends[1].sendChat(w.code, 'x' * 201)), isA<PermissionDeniedException>());
      await w.dispose();
    });

    test('de noche el chat está cerrado y de día hablan los vivos, no los muertos', () async {
      final w = await World.create(6, seed: 42, config: GameConfig.recommended(6).copyWith(cupid: false, blocker: false));
      await w.host.startGame();
      var guard = 0;
      while (w.room.phase != Phase.night && guard++ < 100) {
        w.clock.advance(const Duration(seconds: 1));
        await w.host.tick();
        await settle();
      }
      expect(await errorOf(() => w.backends[1].sendChat(w.code, 'de noche')), isA<PermissionDeniedException>());
      // Pasa a la discusión sin que actúen los bots (nadie muere de noche).
      guard = 0;
      while (w.room.phase != Phase.discussion && guard++ < 400) {
        w.clock.advance(const Duration(seconds: 1));
        await w.host.tick();
        await settle();
      }
      expect(w.room.phase, Phase.discussion);
      await w.backends[1].sendChat(w.code, 'de día');
      // Un jugador eliminado ya no puede escribir.
      await w.host.advance();
      await settle();
      // Abandona un civil (así la partida no termina y el chat sigue sujeto a las reglas).
      final civ = w.host.state!.players.firstWhere((p) => p.role == RoleId.civilian);
      final b = w.backends[int.parse(civ.uid.substring(1))];
      await b.leaveRoom(w.code, inGame: true);
      await settle();
      expect(w.server.membersOf(w.code)[civ.uid]!.alive, false);
      expect(w.room.phase, Phase.voting);
      expect(await errorOf(() => b.sendChat(w.code, 'desde el más allá')),
          isA<PermissionDeniedException>());
      await w.dispose();
    });

    test('los bots charlan en el debate y la partida sigue terminando', () async {
      final w = await World.create(8, seed: 43);
      await w.host.startGame();
      var chats = 0;
      await w.playToEnd(onTick: (r) {
        if (r.phase == Phase.discussion) {
          chats = w.server.chatCount(w.code);
        }
      });
      expect(chats, greaterThan(0));
      expectFinishedCleanly(w, 8);
      await w.dispose();
    });
  });

  group('Bots que respetan a un jugador protegido', () {
    test('nunca lo atacan ni lo votan', () async {
      for (final seed in [51, 52, 53]) {
        final w = await World.create(8, seed: seed);
        for (final b in w.bots) {
          b.spare = {'u0'};
        }
        await w.host.startGame();
        var u0Died = false;
        await w.playToEnd(onTick: (r) {
          final m = w.server.membersOf(w.code)['u0'];
          if (m != null && !m.alive) u0Died = true;
        });
        // u0 nunca es atacado por asesinos ni votado por bots; sólo podría
        // caer por la cadena de enamorados, que aquí es posible con Cupido.
        if (!w.host.state!.lovers.contains('u0')) {
          expect(u0Died, false, reason: 'semilla $seed');
        }
        await w.dispose();
      }
    });
  });

  group('Revancha', () {
    test('tras terminar se puede volver al lobby y jugar otra partida', () async {
      final w = await World.create(7, seed: 23);
      await w.host.startGame();
      await w.playToEnd();
      expect(w.room.phase, Phase.finished);
      await w.host.rematch();
      await settle();
      expect(w.room.phase, Phase.lobby);
      expect(w.room.winner, isNull);
      expect(w.room.finalRoles, isEmpty);
      expect(w.server.membersOf(w.code).values.every((m) => m.alive && m.revealedRole == null), true);
      await w.host.startGame();
      for (final b in w.bots) {
        b.reset();
      }
      await w.playToEnd();
      expectFinishedCleanly(w, 7);
      await w.dispose();
    });
  });
}
