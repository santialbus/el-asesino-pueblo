import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/settings.dart';

bool stillMotion(BuildContext context, WidgetRef ref) =>
    ref.watch(settingsProvider).reduceMotion ||
    MediaQuery.disableAnimationsOf(context);

/// Aparece con un fundido y un ligero desplazamiento tras `index * stepMs`.
/// Sirve para revelar listas de una en una (muertes, escrutinio, roles finales).
/// Con "reducir animaciones" aparece al instante.
class Staggered extends ConsumerStatefulWidget {
  const Staggered({
    super.key,
    required this.child,
    this.index = 0,
    this.stepMs = 140,
    this.baseMs = 150,
  });
  final Widget child;
  final int index;
  final int stepMs;
  final int baseMs;

  @override
  ConsumerState<Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends ConsumerState<Staggered> {
  bool _shown = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(
      Duration(milliseconds: widget.baseMs + widget.index * widget.stepMs),
      () {
        if (mounted) setState(() => _shown = true);
      },
    );
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (stillMotion(context, ref)) return widget.child;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Destello de pantalla de un solo disparo (viñeta de color que sube y baja).
/// Se dispara cada vez que cambia [trigger] (si no es null). Colocar dentro de
/// un [Stack] a pantalla completa; no intercepta toques.
class FlashOverlay extends ConsumerStatefulWidget {
  const FlashOverlay({
    super.key,
    required this.trigger,
    required this.color,
    this.peak = 0.55,
  });
  final Object? trigger;
  final Color color;
  final double peak;

  @override
  ConsumerState<FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends ConsumerState<FlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.trigger != null) _c.forward();
  }

  @override
  void didUpdateWidget(FlashOverlay old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null && widget.trigger != old.trigger)
      _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (stillMotion(context, ref)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          // Sube rápido y baja despacio.
          final v = _c.value;
          final a = v < 0.25
              ? v / 0.25
              : math.pow(1 - (v - 0.25) / 0.75, 2).toDouble();
          if (_c.isDismissed || a <= 0.001) return const SizedBox.expand();
          return SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    widget.color.withValues(alpha: widget.peak * a),
                  ],
                  stops: const [0.25, 1],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sol que asoma sobre el horizonte (cabecera del amanecer).
class SunriseGlow extends ConsumerWidget {
  const SunriseGlow({super.key, this.height = 110});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final still = stillMotion(context, ref);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 2600),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(painter: _SunPainter(t)),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  _SunPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final horizon = s.height * 0.86;
    final cx = s.width / 2;
    final r = s.height * 0.26;
    // El sol sube desde por debajo del horizonte.
    final cy = horizon + r * 0.9 - (r * 0.9 + s.height * 0.38) * t;
    final glow = Rect.fromCircle(center: Offset(cx, cy), radius: r * 3.2);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s.width, horizon));
    canvas.drawCircle(
      Offset(cx, cy),
      r * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD9A0).withValues(alpha: 0.45 * t),
            Colors.transparent,
          ],
        ).createShader(glow),
    );
    // Rayos
    final ray = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.35 * t)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 11; i++) {
      final a = math.pi + (i + 0.5) * math.pi / 11;
      canvas.drawLine(
        Offset(cx + math.cos(a) * r * 1.25, cy + math.sin(a) * r * 1.25),
        Offset(
          cx + math.cos(a) * r * (1.6 + 0.9 * t),
          cy + math.sin(a) * r * (1.6 + 0.9 * t),
        ),
        ray,
      );
    }
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFFF4D9A8),
    );
    canvas.restore();
    canvas.drawLine(
      Offset(s.width * 0.2, horizon),
      Offset(s.width * 0.8, horizon),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.t != t;
}
