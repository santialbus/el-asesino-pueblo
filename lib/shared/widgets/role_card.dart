import 'dart:math' as math;

import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/settings.dart';

Color teamColor(Team t) => switch (t) {
  Team.assassins => AppColors.danger,
  Team.town => AppColors.town,
  Team.neutral => AppColors.gold,
};

/// Emblema de cada personaje, dibujado con líneas doradas (sin emojis ni
/// imágenes externas). Legible desde 40 px.
class RoleArt extends StatelessWidget {
  const RoleArt({super.key, required this.role, this.size = 120, this.color});
  final RoleId role;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _ArtPainter(role, color ?? AppColors.gold)),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.role, this.color);
  final RoleId role;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    Offset p(double x, double y) => Offset(x * w, y * w);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.035)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final solid = Paint()..color = color;

    switch (role) {
      case RoleId.assassin:
        final blade = Path()
          ..moveTo(p(.5, .10).dx, p(.5, .10).dy)
          ..lineTo(p(.60, .56).dx, p(.60, .56).dy)
          ..lineTo(p(.40, .56).dx, p(.40, .56).dy)
          ..close();
        canvas.drawPath(blade, fill);
        canvas.drawPath(blade, stroke);
        canvas.drawLine(
          p(.5, .16),
          p(.5, .54),
          stroke..strokeWidth = stroke.strokeWidth * 0.5,
        );
        stroke.strokeWidth = math.max(1.4, w * 0.035);
        canvas.drawLine(p(.28, .58), p(.72, .58), stroke);
        canvas.drawLine(p(.5, .58), p(.5, .80), stroke);
        canvas.drawCircle(p(.5, .85), w * 0.045, solid);
        // gotas
        canvas.drawCircle(p(.30, .30), w * 0.018, solid);
        canvas.drawCircle(p(.70, .38), w * 0.014, solid);
      case RoleId.police:
        canvas.drawCircle(p(.5, .5), w * 0.40, stroke);
        canvas.drawCircle(
          p(.5, .5),
          w * 0.34,
          stroke..strokeWidth = stroke.strokeWidth * 0.4,
        );
        stroke.strokeWidth = math.max(1.4, w * 0.035);
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final r = (i.isEven ? 0.25 : 0.105) * w;
          final a = -math.pi / 2 + i * math.pi / 5;
          final o = Offset(w * .5 + r * math.cos(a), w * .5 + r * math.sin(a));
          i == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
        }
        star.close();
        canvas.drawPath(star, fill);
        canvas.drawPath(star, stroke);
      case RoleId.doctor:
        canvas.drawCircle(p(.5, .5), w * 0.40, stroke);
        final cross = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: p(.5, .5),
                width: w * 0.2,
                height: w * 0.52,
              ),
              Radius.circular(w * .03),
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: p(.5, .5),
                width: w * 0.52,
                height: w * 0.2,
              ),
              Radius.circular(w * .03),
            ),
          );
        canvas.drawPath(cross, fill);
        canvas.drawPath(cross, stroke);
      case RoleId.cupid:
        final heart = Path()
          ..moveTo(p(.5, .80).dx, p(.5, .80).dy)
          ..cubicTo(
            p(.08, .52).dx,
            p(.08, .52).dy,
            p(.16, .18).dx,
            p(.16, .18).dy,
            p(.5, .34).dx,
            p(.5, .34).dy,
          )
          ..cubicTo(
            p(.84, .18).dx,
            p(.84, .18).dy,
            p(.92, .52).dx,
            p(.92, .52).dy,
            p(.5, .80).dx,
            p(.5, .80).dy,
          );
        canvas.drawPath(heart, fill);
        canvas.drawPath(heart, stroke);
        canvas.drawLine(p(.12, .88), p(.88, .12), stroke);
        final head = Path()
          ..moveTo(p(.88, .12).dx, p(.88, .12).dy)
          ..lineTo(p(.70, .14).dx, p(.70, .14).dy)
          ..lineTo(p(.86, .30).dx, p(.86, .30).dy)
          ..close();
        canvas.drawPath(head, solid);
        canvas.drawLine(p(.12, .88), p(.22, .78), stroke);
        canvas.drawLine(p(.12, .88), p(.24, .90), stroke);
      case RoleId.blocker:
        final mask = Path()
          ..moveTo(p(.10, .40).dx, p(.10, .40).dy)
          ..quadraticBezierTo(
            p(.5, .26).dx,
            p(.5, .26).dy,
            p(.90, .40).dx,
            p(.90, .40).dy,
          )
          ..quadraticBezierTo(
            p(.84, .70).dx,
            p(.84, .70).dy,
            p(.62, .64).dx,
            p(.62, .64).dy,
          )
          ..quadraticBezierTo(
            p(.5, .57).dx,
            p(.5, .57).dy,
            p(.38, .64).dx,
            p(.38, .64).dy,
          )
          ..quadraticBezierTo(
            p(.16, .70).dx,
            p(.16, .70).dy,
            p(.10, .40).dx,
            p(.10, .40).dy,
          )
          ..close();
        canvas.drawPath(mask, fill);
        canvas.drawPath(mask, stroke);
        canvas.drawOval(
          Rect.fromCenter(center: p(.31, .47), width: w * .18, height: w * .09),
          solid,
        );
        canvas.drawOval(
          Rect.fromCenter(center: p(.69, .47), width: w * .18, height: w * .09),
          solid,
        );
        canvas.drawLine(p(.10, .40), p(.02, .32), stroke);
        canvas.drawLine(p(.90, .40), p(.98, .32), stroke);
      case RoleId.civilian:
        final roof = Path()
          ..moveTo(p(.16, .46).dx, p(.16, .46).dy)
          ..lineTo(p(.5, .16).dx, p(.5, .16).dy)
          ..lineTo(p(.84, .46).dx, p(.84, .46).dy)
          ..close();
        canvas.drawPath(roof, fill);
        canvas.drawPath(roof, stroke);
        final body = Rect.fromLTRB(w * .26, w * .46, w * .74, w * .82);
        canvas.drawRect(body, stroke);
        canvas.drawRect(
          Rect.fromLTRB(w * .44, w * .60, w * .56, w * .82),
          stroke,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .31, w * .52, w * .40, w * .60),
          solid,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .60, w * .52, w * .69, w * .60),
          solid,
        );
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.role != role || old.color != color;
}

/// Carta con giro 3D. Reverso común; anverso con marco, emblema, equipo y
/// habilidad (el texto de habilidad se oculta en tamaños muy pequeños).
class RoleCard extends ConsumerWidget {
  const RoleCard({
    super.key,
    required this.role,
    required this.team,
    required this.faceUp,
    this.width = 220,
  });
  final RoleId role;
  final Team team;
  final bool faceUp;
  final double width;

  double get height => width * 1.55;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final still =
        ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: faceUp ? 1.0 : 0.0),
      duration: still ? Duration.zero : const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final showFront = t > 0.5;
        final angle = t * math.pi;
        return Semantics(
          label: faceUp
              ? 'Carta: ${RoleInfo.of(role).name}'
              : 'Carta boca abajo',
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: SizedBox(
              width: width,
              height: height,
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _front(),
                    )
                  : _back(),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _frame(List<Color> colors) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ),
    borderRadius: BorderRadius.circular(width * 0.06),
    border: Border.all(color: AppColors.gold, width: 1.6),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.6),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );

  Widget _back() => Container(
    decoration: _frame([
      const Color(0xFF8A2740),
      AppColors.burgundy,
      const Color(0xFF4A1322),
    ]),
    child: Padding(
      padding: EdgeInsets.all(width * 0.05),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.03),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: CustomPaint(
          painter: _BackPainter(),
          child: Center(
            child: Container(
              width: width * 0.36,
              height: width * 0.36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3A0F1B),
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: Text(
                'EA',
                style: AppText.title(
                  width * 0.12,
                  color: AppColors.gold,
                  spacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _front() {
    final info = RoleInfo.of(role);
    final tc = teamColor(team);
    final big = width >= 150;
    return Container(
      decoration: _frame([AppColors.bg2, const Color(0xFF0E0D12)]),
      child: Padding(
        padding: EdgeInsets.all(width * 0.05),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.03),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.06,
              vertical: width * 0.05,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 11,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width * 0.03),
                      gradient: RadialGradient(
                        colors: [
                          tc.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: RoleArt(role: role, size: width * 0.62),
                    ),
                  ),
                ),
                SizedBox(height: width * 0.03),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    info.name.toUpperCase(),
                    style: AppText.title(width * 0.095, spacing: 1.5),
                  ),
                ),
                SizedBox(height: width * 0.02),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.05,
                    vertical: width * 0.012,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: tc, width: 1),
                    borderRadius: BorderRadius.circular(width),
                  ),
                  child: Text(
                    teamName(team).toUpperCase(),
                    style: AppText.label(width * 0.05, color: tc),
                  ),
                ),
                if (big) ...[
                  SizedBox(height: width * 0.035),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: Text(
                        info.ability,
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        overflow: TextOverflow.fade,
                        style: AppText.body(
                          width * 0.058,
                          color: AppColors.text2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const step = 22.0;
    for (var x = -s.height; x < s.width + s.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + s.height, s.height), p);
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
