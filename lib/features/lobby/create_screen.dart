import 'dart:math';

import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/settings.dart';
import '../../shared/widgets/backdrop.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../game/application/providers.dart';

String friendlyError(Object e) {
  if (e is RoomExistsException ||
      e is RoomNotFoundException ||
      e is RoomNotJoinableException ||
      e is PermissionDeniedException ||
      e is QuotaExceededException ||
      e is VersionConflictException ||
      e is GameStartException) {
    return e.toString();
  }
  return 'Algo ha fallado. Comprueba tu conexión e inténtalo de nuevo.';
}

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  late final TextEditingController _name = TextEditingController(
    text: ref.read(settingsProvider).playerName,
  );
  final TextEditingController _room = TextEditingController();
  double _players = 8;
  NarratorMode _mode = NarratorMode.auto;
  bool _hostPlays = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'Escribe tu nombre.');
      return;
    }
    setState(() => _busy = true);
    final backend = ref.read(backendProvider);
    final rng = Random.secure();
    final n = _players.round();
    final plays = _mode == NarratorMode.auto || _hostPlays;
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        final code = RoomCodes.generate(rng);
        final now = DateTime.now().millisecondsSinceEpoch;
        final room = RoomDoc(
          code: code,
          name: _room.text.trim().isEmpty ? 'Sala de $name' : _room.text.trim(),
          hostUid: backend.uid,
          narrator: _mode,
          phase: Phase.lobby,
          round: 0,
          version: 1,
          config: GameConfig.recommended(n, narrator: _mode),
          createdAtMs: now,
        );
        try {
          await backend.createRoom(
            room,
            MemberDoc(
              uid: backend.uid,
              name: name,
              joinedAtMs: now,
              isNarrator: !plays,
            ),
          );
        } on RoomExistsException {
          continue;
        }
        final s = ref.read(settingsProvider);
        ref
            .read(settingsProvider.notifier)
            .update(s.copyWith(playerName: name));
        ref.read(sessionProvider.notifier).enter(code);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      if (mounted)
        showMessage(
          context,
          'No se pudo generar un código libre. Inténtalo otra vez.',
        );
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _players.round();
    final preset = GameConfig.recommended(n);
    return AsesinoPage(
      title: 'Crear partida',
      scene: Scene.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 56),
          AsesinoField(controller: _name, label: 'Tu nombre', maxLength: 20),
          const SizedBox(height: 14),
          AsesinoField(
            controller: _room,
            label: 'Nombre de la sala (opcional)',
            maxLength: 40,
          ),
          const SectionLabel('Jugadores previstos'),
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
            'Preset: ${preset.assassins} ${preset.assassins == 1 ? "asesino" : "asesinos"}, '
            '${preset.police} policía, ${preset.doctors} médico'
            '${preset.cupid ? ", Cupido y La Puta" : ""}. '
            'Podrás ajustarlo en el lobby.',
            style: AppText.body(13, color: AppColors.text2),
          ),
          const SectionLabel('Narrador'),
          SegmentedButton<NarratorMode>(
            segments: const [
              ButtonSegment(
                value: NarratorMode.auto,
                label: Text('Automático'),
                icon: Icon(Icons.auto_awesome),
              ),
              ButtonSegment(
                value: NarratorMode.human,
                label: Text('Humano'),
                icon: Icon(Icons.record_voice_over),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == NarratorMode.auto
                ? 'El juego guía las fases con temporizadores y textos en pantalla.'
                : 'Una persona dirige la partida desde un panel de moderación y ve todos los roles.',
            style: AppText.body(13, color: AppColors.text2),
          ),
          if (_mode == NarratorMode.human)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('El narrador también juega', style: AppText.body(15)),
              value: _hostPlays,
              onChanged: (v) => setState(() => _hostPlays = v),
            ),
          const SizedBox(height: 28),
          GoldButton(
            label: _busy ? 'Creando…' : 'Crear sala',
            onPressed: _busy ? null : _create,
          ),
        ],
      ),
    );
  }
}
