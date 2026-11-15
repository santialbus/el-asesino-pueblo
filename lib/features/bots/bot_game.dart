import 'dart:math';

import 'package:asesino_core/asesino_core.dart';
import 'package:asesino_core/asesino_core_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/settings.dart';
import '../../shared/widgets/backdrop.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../game/application/providers.dart';
import '../game/data/switchable_backend.dart';
import '../game/presentation/room_screen.dart';
import '../lobby/create_screen.dart' show friendlyError;
import 'tutorial.dart';

/// Configuración rápida de una partida de pruebas contra bots.
class BotSetupScreen extends ConsumerStatefulWidget {
  const BotSetupScreen({super.key});

  @override
  ConsumerState<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends ConsumerState<BotSetupScreen> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(settingsProvider).playerName.isEmpty
        ? 'Tú'
        : ref.read(settingsProvider).playerName,
  );
  double _players = 8;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _players.round();
    return AsesinoPage(
      title: 'Partida con bots',
      scene: Scene.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 56),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Modo de pruebas. Juegas tú solo contra jugadores simulados, en este '
              'dispositivo y sin conexión a Firebase. Eres el anfitrión y usas las '
              'mismas pantallas y el mismo motor que una partida real. Los bots '
              'actúan y votan al azar.',
              style: AppText.body(14, color: AppColors.text2),
            ),
          ),
          const SizedBox(height: 18),
          AsesinoField(controller: _name, label: 'Tu nombre', maxLength: 20),
          const SectionLabel('Jugadores en total'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _players,
                  min: 5,
                  max: 20,
                  divisions: 15,
                  label: '$n',
                  onChanged: (v) => setState(() => _players = v),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$n',
                  style: AppText.title(22),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          Text(
            'Tú + ${n - 1} bots. Los tiempos por defecto son cortos para probar rápido '
            '(puedes cambiarlos en el lobby).',
            style: AppText.body(13, color: AppColors.text2),
          ),
          const SizedBox(height: 28),
          GoldButton(
            label: 'Empezar',
            icon: Icons.smart_toy_outlined,
            onPressed: () {
              final name = _name.text.trim().isEmpty ? 'Tú' : _name.text.trim();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BotGameScreen(playerName: name, players: n),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Monta una sala local en memoria con bots y muestra la sala real.
class BotGameScreen extends ConsumerStatefulWidget {
  const BotGameScreen({
    super.key,
    required this.playerName,
    required this.players,
    this.tutorial = false,
  });
  final String playerName;
  final int players;

  /// Partida guiada: tú de Policía, bots que no te atacan y tarjetas guía.
  final bool tutorial;

  @override
  ConsumerState<BotGameScreen> createState() => _BotGameScreenState();
}

class _BotGameScreenState extends ConsumerState<BotGameScreen> {
  late final SwitchableBackend _switch;
  BotDriver? _driver;
  String? _code;
  String? _error;
  TutorialPlan? _plan;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final b = ref.read(backendProvider);
    _switch = b as SwitchableBackend;
    _setup();
  }

  Future<void> _setup() async {
    try {
      final rng = Random();
      final plan = widget.tutorial ? const TutorialPlan() : null;
      final total = plan?.players ?? widget.players;
      final server = InMemoryServer(RealClock());
      final me = server.client('tu');
      final code = RoomCodes.generate(rng);
      final now = DateTime.now().millisecondsSinceEpoch;
      final cfg =
          plan?.config ??
          GameConfig.recommended(total).copyWith(
            discussionSeconds: 60,
            votingSeconds: 30,
            nightStepSeconds: 15,
          );
      final room = RoomDoc(
        code: code,
        name: widget.tutorial ? 'Tutorial' : 'Partida con bots',
        hostUid: me.uid,
        narrator: NarratorMode.auto,
        phase: Phase.lobby,
        round: 0,
        version: 1,
        config: cfg,
        createdAtMs: now,
      );
      await me.createRoom(
        room,
        MemberDoc(uid: me.uid, name: widget.playerName, joinedAtMs: now),
      );

      final bots = <BotPlayer>[];
      for (var i = 0; i < total - 1; i++) {
        final backend = server.client('bot$i');
        await backend.joinRoom(
          code,
          MemberDoc(
            uid: backend.uid,
            name: kBotNames[i % kBotNames.length],
            joinedAtMs: now + i + 1,
          ),
        );
        final bot = BotPlayer(backend, code, Random(rng.nextInt(1 << 30)));
        if (plan != null)
          bot.spare = {...plan.spare}; // no atacan ni votan al jugador
        bots.add(bot);
      }
      _driver = BotDriver(bots, rng: rng)..start();
      _switch.useLocal(me);
      _plan = plan;
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _cleanup() async {
    if (_closed) return;
    _closed = true;
    _switch.useRemote();
    final d = _driver;
    _driver = null;
    await d?.stop();
  }

  void _exit() {
    _cleanup();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AsesinoPage(
        title: widget.tutorial ? 'Tutorial' : 'Partida con bots',
        child: Column(
          children: [
            const SizedBox(height: 80),
            Text(_error!, textAlign: TextAlign.center, style: AppText.body(16)),
          ],
        ),
      );
    }
    if (_code == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    return RoomScreen(code: _code!, onLocalExit: _exit, tutorial: _plan);
  }
}
