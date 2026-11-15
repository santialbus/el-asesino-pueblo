import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/settings.dart';
import '../../shared/widgets/backdrop.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../bots/bot_game.dart';
import '../game/application/providers.dart';
import '../lobby/create_screen.dart';
import '../lobby/join_screen.dart';
import '../settings/info_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La música del menú arranca con el primer toque (el navegador exige un gesto).
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(audioProvider).setTrack(Track.menu),
      child: _page(context, ref),
    );
  }

  Widget _page(BuildContext context, WidgetRef ref) {
    return AsesinoPage(
      scene: Scene.night,
      village: true,
      back: false,
      scroll: false,
      maxWidth: 440,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  label: 'El Asesino, el pueblo duerme',
                  child: Column(
                    children: [
                      Text(
                        'EL',
                        style: AppText.label(16, color: AppColors.text2),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'ASESINO',
                          style: AppText.title(54, spacing: 8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const OrnamentDivider(width: 200),
                      const SizedBox(height: 14),
                      Text('EL PUEBLO DUERME', style: AppText.label(14)),
                    ],
                  ),
                ),
                const SizedBox(height: 64),
                GoldButton(
                  label: 'Jugar',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _play(context),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    GhostButton(
                      label: 'Ajustes',
                      icon: Icons.tune,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    GhostButton(
                      label: 'Cómo se juega',
                      icon: Icons.menu_book_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const InfoScreen(),
                        ),
                      ),
                    ),
                    GhostButton(
                      label: 'Tutorial guiado',
                      icon: Icons.school_outlined,
                      onPressed: () {
                        final name = ref.read(settingsProvider).playerName;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BotGameScreen(
                              playerName: name.isEmpty ? 'Tú' : name,
                              players: 7,
                              tutorial: true,
                            ),
                          ),
                        );
                      },
                    ),
                    GhostButton(
                      label: 'Partida con bots (pruebas)',
                      icon: Icons.smart_toy_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BotSetupScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _play(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('¿CÓMO QUIERES JUGAR?', style: AppText.label(13)),
              const SizedBox(height: 20),
              GoldButton(
                label: 'Crear partida',
                icon: Icons.add,
                onPressed: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              GoldButton(
                label: 'Unirse a partida',
                icon: Icons.login,
                onPressed: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const JoinScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
