import 'dart:async';

import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'role_card.dart';

/// Cuenta atrás local: se reinicia cuando cambia [resetKey] (la versión de la
/// sala). No escribe nada en Firestore ni depende de relojes sincronizados.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.durationMs,
    required this.resetKey,
    this.size = 28,
  });
  final int durationMs;
  final Object resetKey;
  final double size;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late DateTime _start = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(Countdown old) {
    super.didUpdateWidget(old);
    if (old.resetKey != widget.resetKey ||
        old.durationMs != widget.durationMs) {
      _start = DateTime.now();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.durationMs <= 0) return const SizedBox.shrink();
    final left =
        widget.durationMs - DateTime.now().difference(_start).inMilliseconds;
    final secs = (left / 1000).ceil().clamp(0, 99999);
    final text =
        '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    final urgent = secs <= 10;
    return Semantics(
      label: 'Tiempo restante: $secs segundos',
      child: Text(
        text,
        style: AppText.title(
          widget.size,
          color: urgent ? AppColors.danger : AppColors.gold,
          spacing: 3,
        ),
      ),
    );
  }
}

/// Ficha de un jugador: avatar con inicial, nombre y estado.
class PlayerTile extends StatelessWidget {
  const PlayerTile({
    super.key,
    required this.member,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.isHost = false,
    this.isMe = false,
    this.badge,
    this.trailing,
  });

  final MemberDoc member;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isHost;
  final bool isMe;
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dead = !member.alive;
    final initial = member.name.isEmpty
        ? '?'
        : String.fromCharCode(member.name.runes.first).toUpperCase();
    final border = selected
        ? AppColors.gold
        : AppColors.gold.withValues(alpha: 0.18);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label:
          '${member.name}${dead ? ", eliminado" : ""}${selected ? ", seleccionado" : ""}',
      child: Opacity(
        opacity: (enabled || selected) ? (dead ? 0.55 : 1) : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: enabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.burgundy.withValues(alpha: 0.55)
                    : AppColors.bg2.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border, width: selected ? 1.6 : 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(
                          alpha: dead ? 0.3 : 0.8,
                        ),
                      ),
                      color: AppColors.bg,
                    ),
                    child: Text(initial, style: AppText.title(16, spacing: 0)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name + (isMe ? '  (tú)' : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(16, bold: true).copyWith(
                            decoration: dead
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.danger,
                          ),
                        ),
                        if (badge != null ||
                            (dead && member.revealedRole != null))
                          Text(
                            badge ?? RoleInfo.of(member.revealedRole!).name,
                            style: AppText.body(12, color: AppColors.text2),
                          ),
                      ],
                    ),
                  ),
                  if (isHost)
                    const Icon(
                      Icons.workspace_premium,
                      size: 18,
                      color: AppColors.gold,
                    ),
                  if (!dead && !member.isNarrator)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Tooltip(
                        message: member.online ? 'Conectado' : 'Sin conexión',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: member.online
                                ? AppColors.town
                                : AppColors.text2,
                          ),
                        ),
                      ),
                    ),
                  if (member.isNarrator)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('NARRADOR', style: AppText.label(10)),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto de narración con marco discreto.
class NarrationText extends StatelessWidget {
  const NarrationText(this.text, {super.key, this.size = 18});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: AppText.body(
          size,
          color: AppColors.text,
        ).copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// Cabecera de fase: etiqueta pequeña + título.
class PhaseHeader extends StatelessWidget {
  const PhaseHeader({
    super.key,
    required this.label,
    required this.title,
    this.trailing,
  });
  final String label;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppText.label(11)),
              const SizedBox(height: 4),
              Text(title, style: AppText.title(24)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Mini etiqueta de equipo.
class TeamChip extends StatelessWidget {
  const TeamChip(this.team, {super.key});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final c = teamColor(team);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        teamName(team).toUpperCase(),
        style: AppText.label(11, color: c),
      ),
    );
  }
}
