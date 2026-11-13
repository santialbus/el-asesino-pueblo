import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';

/// Botón principal: marco dorado fino sobre burdeos. Objetivo táctil >= 52 px.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = danger ? AppColors.danger : AppColors.burgundy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: BoxConstraints(
                minHeight: compact ? 44 : 54,
                minWidth: 120,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 28,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [base, Color.lerp(base, Colors.black, 0.35)!],
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.85),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppText.label(
                        compact ? 12 : 14,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón secundario: sólo texto con subrayado dorado.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.text2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppText.body(14, color: AppColors.text2)),
          ],
        ),
      ),
    );
  }
}

/// Línea fina con un rombo central.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.width = 160});
  final double width;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: AppColors.gold.withValues(alpha: 0.45),
      ),
    );
    return SizedBox(
      width: width,
      child: Row(
        children: [
          line,
          const SizedBox(width: 8),
          Transform.rotate(
            angle: 0.785398,
            child: Container(width: 7, height: 7, color: AppColors.gold),
          ),
          const SizedBox(width: 8),
          line,
        ],
      ),
    );
  }
}

/// Campo de texto con el estilo del juego (sin depender de temas de Material).
class AsesinoField extends StatelessWidget {
  const AsesinoField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength,
    this.caps = false,
    this.center = false,
    this.onChanged,
    this.hint,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final int? maxLength;
  final bool caps;
  final bool center;
  final ValueChanged<String>? onChanged;
  final String? hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      autofocus: autofocus,
      onChanged: onChanged,
      textAlign: center ? TextAlign.center : TextAlign.start,
      textCapitalization: caps
          ? TextCapitalization.characters
          : TextCapitalization.words,
      inputFormatters: caps
          ? [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              _UpperCase(),
            ]
          : null,
      cursorColor: AppColors.gold,
      style: caps ? AppText.title(26, spacing: 8) : AppText.body(17),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        labelStyle: AppText.body(14, color: AppColors.text2),
        floatingLabelStyle: AppText.body(13, color: AppColors.gold),
        filled: true,
        fillColor: AppColors.bg2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue value,
  ) => value.copyWith(text: value.text.toUpperCase());
}

/// Título de sección pequeño en mayúsculas.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text.toUpperCase(), style: AppText.label(12)),
  );
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
