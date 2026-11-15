import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/platform/link.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/game_widgets.dart';
import 'config_sheet.dart';
import 'create_screen.dart' show friendlyError;

class LobbyView extends StatelessWidget {
  const LobbyView({
    super.key,
    required this.room,
    required this.members,
    required this.host,
    required this.myUid,
    required this.onLeave,
  });

  final RoomDoc room;
  final List<MemberDoc> members;
  final HostCoordinator? host;
  final String myUid;
  final VoidCallback onLeave;

  bool get isHost => host != null && room.hostUid == myUid;

  List<MemberDoc> get _sorted => [...members]
    ..sort((a, b) {
      final c = a.joinedAtMs.compareTo(b.joinedAtMs);
      return c != 0 ? c : a.uid.compareTo(b.uid);
    });

  int get _playing => members.where((m) => !m.isNarrator && !m.left).length;

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = isHost
        ? host!.startErrors()
        : room.config.validate(_playing);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('SALA', textAlign: TextAlign.center, style: AppText.label(12)),
        const SizedBox(height: 4),
        Text(room.name, textAlign: TextAlign.center, style: AppText.title(22)),
        const SizedBox(height: 18),
        _CodeCard(code: room.code),
        const SectionLabel('Jugadores'),
        Text(
          '$_playing ${_playing == 1 ? "jugador" : "jugadores"} · entre 5 y 20',
          style: AppText.body(13, color: AppColors.text2),
        ),
        const SizedBox(height: 8),
        for (final m in _sorted)
          if (!m.left)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlayerTile(
                member: m,
                isHost: m.uid == room.hostUid,
                isMe: m.uid == myUid,
                trailing: isHost && m.uid != myUid
                    ? IconButton(
                        tooltip: 'Expulsar a ${m.name}',
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.text2,
                        ),
                        onPressed: () => _run(context, () => host!.kick(m.uid)),
                      )
                    : null,
              ),
            ),
        const SectionLabel('Partida'),
        Text(configSummary(room.config, _playing), style: AppText.body(15)),
        const SizedBox(height: 4),
        Text(
          'Narrador ${room.narrator == NarratorMode.auto ? "automático" : "humano"} · '
          'voto ${room.config.secretVotes ? "secreto" : "público"}',
          style: AppText.body(13, color: AppColors.text2),
        ),
        if (isHost) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: GhostButton(
              label: 'Configurar partida',
              icon: Icons.tune,
              onPressed: () async {
                final res = await showConfigSheet(
                  context,
                  room.config,
                  _playing,
                );
                if (res != null && context.mounted) {
                  await _run(context, () => host!.updateLobby(config: res));
                }
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (errors.isNotEmpty)
          for (final e in errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.text2,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e,
                      style: AppText.body(13, color: AppColors.text2),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        if (isHost)
          GoldButton(
            label: 'Empezar partida',
            icon: Icons.nightlight_round,
            onPressed: errors.isEmpty
                ? () => _run(context, host!.startGame)
                : null,
          )
        else
          Center(
            child: Text(
              'Esperando a que el anfitrión empiece la partida…',
              style: AppText.body(14, color: AppColors.text2),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: GhostButton(
            label: 'Salir de la sala',
            icon: Icons.logout,
            onPressed: onLeave,
          ),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bg2.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text('CÓDIGO DE SALA', style: AppText.label(11)),
          const SizedBox(height: 8),
          Semantics(
            label: 'Código de sala: ${code.split("").join(" ")}',
            child: Text(code, style: AppText.title(40, spacing: 10)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GhostButton(
                label: 'Copiar código',
                icon: Icons.copy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) showMessage(context, 'Código copiado');
                },
              ),
              GhostButton(
                label: 'Copiar invitación',
                icon: Icons.share,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: inviteLink(code) != null
                          ? 'Únete a mi partida de El Asesino: ${inviteLink(code)}  (código: $code)'
                          : 'Únete a mi partida de El Asesino. Código de sala: $code',
                    ),
                  );
                  if (context.mounted)
                    showMessage(context, 'Invitación copiada');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
