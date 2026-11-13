import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../../shared/widgets/role_card.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget p(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t, style: AppText.body(15, color: AppColors.text)),
    );
    return AsesinoPage(
      title: 'Cómo se juega',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 56),
          const SectionLabel('El pueblo duerme'),
          p(
            'Entre los vecinos se esconden uno o varios asesinos. De noche matan; '
            'de día todos debaten, sospechan, mienten y votan a quién expulsar.',
          ),
          p(
            'El pueblo gana si expulsa a todos los asesinos. Los asesinos ganan cuando '
            'igualan en número al resto de vecinos.',
          ),
          const SectionLabel('Personajes'),
          for (final r in RoleId.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: RoleArt(
                      role: r,
                      size: 48,
                      color: teamColor(RoleInfo.of(r).defaultTeam),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          RoleInfo.of(r).name.toUpperCase(),
                          style: AppText.title(15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          RoleInfo.of(r).ability,
                          style: AppText.body(14, color: AppColors.text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SectionLabel('Una partida'),
          p(
            'Noche: cada personaje despierta por turnos y usa su habilidad. '
            'Amanecer: se anuncia quién ha muerto. Debate: el pueblo discute. '
            'Votación: se expulsa al más votado.',
          ),
          const SectionLabel('Sobre la seguridad'),
          p(
            'Esta versión funciona sin servidor propio: el dispositivo del anfitrión '
            'actúa como moderador y puede ver los roles. Es ideal para jugar entre '
            'amigos, pero no está pensada para partidas competitivas con desconocidos.',
          ),
          p(
            'Tu rol sólo se envía a tu dispositivo; los demás jugadores no pueden leerlo.',
          ),
          const SectionLabel('Versión'),
          Text('0.9.0 beta 1', style: AppText.body(13, color: AppColors.text2)),
        ],
      ),
    );
  }
}
