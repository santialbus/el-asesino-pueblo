import 'dart:async';
import 'dart:math';

import 'package:asesino_core/asesino_core.dart';
import 'package:asesino_core/asesino_core_testing.dart';

Future<void> settle([int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Los bots de las pruebas son los mismos que usa el modo local de la app.
typedef Bot = BotPlayer;

class World {
  World._(this.clock, this.server, this.code, this.rng);

  final FakeClock clock;
  final InMemoryServer server;
  final String code;
  final Random rng;
  late HostCoordinator host;
  final List<Bot> bots = [];
  final List<InMemoryBackend> backends = [];

  static Future<World> create(
    int n, {
    GameConfig? config,
    NarratorMode narrator = NarratorMode.auto,
    bool hostPlays = true,
    int seed = 1,
    int extraNarratorSeat = 0,
  }) async {
    final clock = FakeClock();
    final server = InMemoryServer(clock);
    final rng = Random(seed);
    final code = RoomCodes.generate(rng);
    final w = World._(clock, server, code, rng);
    final players = n + (narrator == NarratorMode.human && !hostPlays ? 1 : 0);
    final cfg = (config ?? GameConfig.recommended(n))
        .copyWith(
          discussionSeconds: 10,
          votingSeconds: 10,
          nightStepSeconds: 5,
          narrator: narrator,
        );
    for (var i = 0; i < players; i++) {
      w.backends.add(server.client('u$i'));
    }
    final hostB = w.backends.first;
    final room = RoomDoc(
      code: code,
      name: 'Sala de prueba',
      hostUid: hostB.uid,
      narrator: narrator,
      phase: Phase.lobby,
      round: 0,
      version: 1,
      config: cfg,
      createdAtMs: clock.ms,
    );
    await hostB.createRoom(
      room,
      MemberDoc(
        uid: hostB.uid,
        name: 'Jugador 0',
        joinedAtMs: clock.ms,
        isNarrator: narrator == NarratorMode.human && !hostPlays,
      ),
    );
    for (var i = 1; i < players; i++) {
      clock.advance(const Duration(milliseconds: 5));
      await w.backends[i].joinRoom(
        code,
        MemberDoc(uid: 'u$i', name: 'Jugador $i', joinedAtMs: clock.ms),
      );
    }
    w.host = HostCoordinator(
      backend: hostB,
      roomId: code,
      room: room,
      rng: Random(seed + 100),
      now: clock.now,
    );
    await w.host.start();
    for (final b in w.backends) {
      w.bots.add(Bot(b, code, Random(seed + b.uid.hashCode)));
    }
    await settle();
    return w;
  }

  RoomDoc get room => server.roomDoc(code)!;

  /// Juega hasta el final. En modo humano, el "narrador" avanza cada pocas
  /// iteraciones (tras dar tiempo a que los bots actúen).
  Future<int> playToEnd({
    int maxTicks = 6000,
    HostCoordinator? hostOverride,
    void Function(RoomDoc)? onTick,
  }) async {
    var i = 0;
    for (; i < maxTicks; i++) {
      final r = room;
      onTick?.call(r);
      if (r.phase == Phase.finished) break;
      await settle();
      for (final b in bots) {
        await b.act();
      }
      await settle();
      clock.advance(const Duration(seconds: 1));
      final h = hostOverride ?? host;
      await h.tick();
      if (r.narrator == NarratorMode.human && i % 3 == 2) {
        await h.advance();
      }
      await settle();
    }
    return i;
  }

  Future<void> dispose() async {
    for (final b in bots) {
      await b.dispose();
    }
    await host.stop();
  }
}
