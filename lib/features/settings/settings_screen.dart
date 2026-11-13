import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/settings.dart';
import '../../shared/widgets/page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void set(AppSettings n) => ref.read(settingsProvider.notifier).update(n);
    return AsesinoPage(
      title: 'Ajustes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 56),
          Text('MÚSICA Y VIBRACIÓN', style: AppText.label(12)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Música ambiental', style: AppText.body(16)),
            value: s.music,
            onChanged: (v) => set(s.copyWith(music: v)),
          ),
          _slider(
            'Volumen de la música',
            s.musicVolume,
            s.music,
            (v) => set(s.copyWith(musicVolume: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Vibración', style: AppText.body(16)),
            subtitle: Text(
              'Los eventos de la partida (noche, amanecer, muertes, victoria) se notan con vibración. '
              'Sólo funciona en la app de Android/iOS, no en el navegador.',
              style: AppText.body(12, color: AppColors.text2),
            ),
            value: s.haptics,
            onChanged: (v) => set(s.copyWith(haptics: v)),
          ),
          const SizedBox(height: 12),
          Text('ACCESIBILIDAD', style: AppText.label(12)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Reducir animaciones', style: AppText.body(16)),
            subtitle: Text(
              'Detiene la niebla, el parpadeo y los giros de carta. También se respeta la preferencia del sistema.',
              style: AppText.body(12, color: AppColors.text2),
            ),
            value: s.reduceMotion,
            onChanged: (v) => set(s.copyWith(reduceMotion: v)),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double v,
    bool enabled,
    ValueChanged<double> on,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: AppText.body(13, color: AppColors.text2)),
        ),
        SizedBox(
          width: 170,
          child: Slider(
            value: v,
            onChanged: enabled ? on : null,
            semanticFormatterCallback: (x) => '${(x * 100).round()} por ciento',
          ),
        ),
      ],
    ),
  );
}
