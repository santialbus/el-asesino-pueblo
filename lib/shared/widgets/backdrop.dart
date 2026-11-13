import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/settings.dart';

enum Scene { night, dawn, day, plain }

/// Escenario de fondo: cielo, luna o sol, siluetas del pueblo con ventanas
/// iluminadas y niebla. Todo es vectorial (sin imágenes externas). Las
/// animaciones se detienen con "reducir animaciones" o la preferencia del
/// sistema.
class Backdrop extends ConsumerStatefulWidget {
  const Backdrop({
    super.key,
    required this.scene,
    required this.child,
    this.village = true,
  });
  final Scene scene;
  final Widget child;
  final bool village;

  @override
  ConsumerState<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends ConsumerState<Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    if (still) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _ScenePainter(
                widget.scene,
                still ? 0.37 : _c.value,
                widget.village,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.t, this.village);
  final Scene scene;
  final double t;
  final bool village;

  static final List<Offset> _stars = () {
    final r = math.Random(11);
    return List.generate(
      46,
      (_) => Offset(r.nextDouble(), r.nextDouble() * 0.6),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final (top, bottom) = switch (scene) {
      Scene.night => (const Color(0xFF07070B), const Color(0xFF1E1520)),
      Scene.dawn => (const Color(0xFF241827), const Color(0xFFB2644A)),
      Scene.day => (const Color(0xFF39465A), const Color(0xFFD9BF96)),
      Scene.plain => (AppColors.bg, AppColors.bg2),
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );

    if (scene == Scene.plain) {
      _vignette(canvas, size);
      return;
    }

    final twinkle = t * math.pi * 2;
    if (scene == Scene.night || scene == Scene.dawn) {
      final a = scene == Scene.night ? 1.0 : 0.35;
      for (var i = 0; i < _stars.length; i++) {
        final s = _stars[i];
        final alpha = a * (0.35 + 0.35 * math.sin(twinkle * 2 + i));
        canvas.drawCircle(
          Offset(s.dx * size.width, s.dy * size.height),
          0.9 + (i % 3) * 0.3,
          Paint()
            ..color = AppColors.text.withValues(alpha: alpha.clamp(0.05, 0.9)),
        );
      }
    }

    // Luna o sol.
    final r = math.min(size.width, size.height) * 0.07;
    if (scene == Scene.night) {
      final c = Offset(size.width * 0.78, size.height * 0.17);
      canvas.drawCircle(
        c,
        r * 3,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.text.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 3)),
      );
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFEDE6D6));
      canvas.drawCircle(
        c.translate(r * 0.35, -r * 0.1),
        r * 0.92,
        Paint()..color = const Color(0xFF0C0B10).withValues(alpha: 0.18),
      );
    } else {
      final c = Offset(
        size.width * 0.22,
        size.height * (scene == Scene.dawn ? 0.52 : 0.2),
      );
      canvas.drawCircle(
        c,
        r * 3.2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFD9A0).withValues(alpha: 0.35),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
      );
      canvas.drawCircle(c, r * 0.9, Paint()..color = const Color(0xFFF4D9A8));
    }

    if (village) _village(canvas, size);

    // Niebla: bandas elipsoidales que se desplazan despacio.
    for (var i = 0; i < 3; i++) {
      final dx =
          ((t * (0.5 + i * 0.2) + i * 0.33) % 1.0) * size.width * 1.6 -
          size.width * 0.3;
      final y = size.height * (0.72 + i * 0.07);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx, y),
          width: size.width * 0.9,
          height: size.height * 0.07,
        ),
        Paint()
          ..color = AppColors.text.withValues(
            alpha: scene == Scene.night ? 0.035 : 0.06,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }
    _vignette(canvas, size);
  }

  void _village(Canvas canvas, Size size) {
    final ground = size.height * 0.84;
    final silhouette = Paint()
      ..color = scene == Scene.day
          ? const Color(0xFF2A2630)
          : const Color(0xFF09080C);
    final houses = <(double, double, double)>[
      (0.00, 0.17, 0.09),
      (0.15, 0.13, 0.07),
      (0.27, 0.16, 0.11),
      (0.44, 0.12, 0.06),
      (0.54, 0.18, 0.10),
      (0.71, 0.13, 0.08),
      (0.82, 0.17, 0.12),
    ];
    for (var i = 0; i < houses.length; i++) {
      final (x, w, h) = houses[i];
      final left = x * size.width;
      final width = w * size.width;
      final height = h * size.height;
      final body = Rect.fromLTWH(
        left,
        ground - height,
        width,
        height + size.height * 0.2,
      );
      canvas.drawRect(body, silhouette);
      final roof = Path()
        ..moveTo(left - width * 0.06, ground - height)
        ..lineTo(left + width / 2, ground - height - height * 0.55)
        ..lineTo(left + width * 1.06, ground - height)
        ..close();
      canvas.drawPath(roof, silhouette);
      if (scene != Scene.day) {
        final lit = scene == Scene.night
            ? 0.55 + 0.25 * math.sin(t * math.pi * 2 * 3 + i * 1.7)
            : 0.8;
        final win = Paint()
          ..color = AppColors.gold.withValues(
            alpha: (lit * (i.isEven ? 1 : 0.6)).clamp(0.1, 0.9),
          );
        final ww = width * 0.16;
        canvas.drawRect(
          Rect.fromLTWH(
            left + width * 0.2,
            ground - height * 0.7,
            ww,
            ww * 1.2,
          ),
          win,
        );
        if (i % 3 != 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              left + width * 0.62,
              ground - height * 0.45,
              ww,
              ww * 1.2,
            ),
            win,
          );
        }
      }
    }
    // Campanario
    final tx = size.width * 0.38;
    canvas.drawRect(
      Rect.fromLTWH(
        tx,
        ground - size.height * 0.2,
        size.width * 0.035,
        size.height * 0.3,
      ),
      silhouette,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tx - size.width * 0.005, ground - size.height * 0.2)
        ..lineTo(tx + size.width * 0.0175, ground - size.height * 0.27)
        ..lineTo(tx + size.width * 0.04, ground - size.height * 0.2)
        ..close(),
      silhouette,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, size.height - ground),
      silhouette,
    );
  }

  void _vignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.t != t || old.scene != scene || old.village != village;
}
