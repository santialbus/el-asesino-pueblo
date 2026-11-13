import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/controls.dart';
import '../../lobby/create_screen.dart' show friendlyError;

/// Barra inferior del anfitrión.
///
/// * Narrador humano: texto para leer en voz alta, estado de la fase y botón
///   "Siguiente". Si no juega, accede además al panel secreto.
/// * Narrador automático: sólo un botón discreto para saltar la fase.
class HostBar extends StatelessWidget {
  const HostBar({super.key, required this.host, required this.myUid});
  final HostCoordinator host;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HostSnapshot>(
      stream: host.snapshots,
      initialData: host.snapshot,
      builder: (context, snap) {
        final s = snap.data!;
        final room = s.room;
        final human = room.narrator == NarratorMode.human;
        final me = s.members.where((m) => m.uid == myUid);
        final plays = me.isEmpty ? true : !me.first.isNarrator;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bg2.withValues(alpha: 0.97),
            border: Border(
              top: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            child: human ? _human(context, s, plays) : _auto(context, s),
          ),
        );
      },
    );
  }

  Widget _auto(BuildContext context, HostSnapshot s) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text('Anfitrión', style: AppText.label(10, color: AppColors.text2)),
      const SizedBox(width: 12),
      GhostButton(
        label: 'Saltar fase',
        icon: Icons.skip_next,
        onPressed: () => _advance(context),
      ),
    ],
  );

  Widget _human(BuildContext context, HostSnapshot s, bool plays) {
    final room = s.room;
    final st = s.state;
    String progress = '';
    if (st != null && room.phase == Phase.night && room.nightStep != null) {
      final actors = st.alivePlayersWithRole(room.nightStep!);
      final done = actors.where((p) => s.actedUids.contains(p.uid)).length;
      progress = actors.isEmpty
          ? 'Turno de ${RoleInfo.of(room.nightStep!).name}: nadie vivo con ese rol (finge el turno).'
          : 'Turno de ${RoleInfo.of(room.nightStep!).name}: $done/${actors.length} han actuado.';
    } else if (st != null && room.phase == Phase.voting) {
      final alive = st.alive.length;
      progress = 'Votos recibidos: ${s.votedUids.length}/$alive.';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('NARRADOR · LEE EN VOZ ALTA', style: AppText.label(10)),
        const SizedBox(height: 4),
        if (room.narration.text.isNotEmpty)
          Text(
            room.narration.text,
            style: AppText.body(15).copyWith(fontStyle: FontStyle.italic),
          ),
        if (progress.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(progress, style: AppText.body(13, color: AppColors.text2)),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (!plays && st != null)
              Expanded(
                child: GhostButton(
                  label: 'Panel secreto',
                  icon: Icons.visibility_outlined,
                  onPressed: () => _panel(context, s),
                ),
              ),
            Expanded(
              flex: 2,
              child: GoldButton(
                label: 'Siguiente',
                compact: true,
                icon: Icons.skip_next,
                onPressed: () => _advance(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _advance(BuildContext context) async {
    try {
      await host.advance();
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }

  void _panel(BuildContext context, HostSnapshot s) {
    final st = s.state!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg2,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text('PANEL SECRETO DEL NARRADOR', style: AppText.label(13)),
            const SizedBox(height: 4),
            Text(
              'No lo enseñes a los jugadores.',
              style: AppText.body(13, color: AppColors.danger),
            ),
            const SizedBox(height: 12),
            for (final p in st.players)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.name,
                  style: AppText.body(16).copyWith(
                    decoration: p.alive ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '${RoleInfo.of(p.role).name} · ${teamName(st.teamOf(p.uid))}'
                  '${st.lovers.contains(p.uid) ? " · enamorado/a" : ""}',
                  style: AppText.body(12, color: AppColors.text2),
                ),
                trailing: s.actedUids.contains(p.uid)
                    ? const Icon(Icons.check, color: AppColors.town, size: 18)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
