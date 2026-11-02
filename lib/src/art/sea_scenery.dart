import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../meta/sea_theme.dart';
import 'sea_palette.dart';

/// Full-screen underwater backdrop for a theme. Static: it repaints only when
/// the theme or the size changes.
class SeaScenery extends StatelessWidget {
  const SeaScenery({super.key, required this.theme});

  final SeaTheme theme;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: SeaSceneryPainter(SeaPalette.of(theme)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SeaSceneryPainter extends CustomPainter {
  const SeaSceneryPainter(this.palette);

  final SeaPalette palette;

  SeaTheme get theme => palette.theme;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.waterTop, palette.waterBottom],
        ).createShader(rect),
    );
    if (theme == SeaTheme.moonlit) _moon(canvas, size);
    if (theme == SeaTheme.polar) _ice(canvas, size);
    _rays(canvas, size);
    _farReef(canvas, size);
    _floor(canvas, size);
    _weeds(canvas, size);
    if (theme == SeaTheme.coral) _corals(canvas, size);
    _bubbles(canvas, size);
    if (theme == SeaTheme.moonlit) _glowSpecks(canvas, size);
  }

  void _rays(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.ray, palette.ray.withValues(alpha: 0)],
      ).createShader(Offset.zero & Size(size.width, size.height * 0.8));
    final rng = math.Random(7);
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.08 + i * 0.17 + rng.nextDouble() * 0.05);
      final w = size.width * (0.03 + rng.nextDouble() * 0.04);
      final slant = size.width * 0.12;
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + w, 0)
          ..lineTo(x + w * 2.4 + slant, size.height * 0.8)
          ..lineTo(x + slant, size.height * 0.8)
          ..close(),
        paint,
      );
    }
  }

  void _farReef(Canvas canvas, Size size) {
    final base = size.height * 0.8;
    final color = Color.lerp(
      palette.waterBottom,
      palette.rock,
      0.35,
    )!.withValues(alpha: 0.55);
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, base);
    const bumps = 7;
    for (var i = 0; i < bumps; i++) {
      final x0 = size.width * i / bumps;
      final x1 = size.width * (i + 1) / bumps;
      final peak = base - size.height * (0.05 + 0.04 * ((i * 37) % 5) / 4);
      path.quadraticBezierTo((x0 + x1) / 2, peak, x1, base);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _floor(Canvas canvas, Size size) {
    final top = size.height * 0.88;
    final sand = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top + size.height * 0.02)
      ..cubicTo(
        size.width * 0.25,
        top - size.height * 0.03,
        size.width * 0.55,
        top + size.height * 0.05,
        size.width,
        top - size.height * 0.01,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      sand,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.sand, palette.sandShade],
        ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top)),
    );
    // Pebbles and shells.
    final rng = math.Random(11);
    final pebble = Paint()..color = palette.sandShade;
    for (var i = 0; i < 18; i++) {
      final x = rng.nextDouble() * size.width;
      final y =
          top + size.height * 0.04 + rng.nextDouble() * size.height * 0.07;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 6 + rng.nextDouble() * 8,
          height: 3 + rng.nextDouble() * 4,
        ),
        pebble,
      );
    }
    // Rocks at both edges.
    final rock = Paint()..color = palette.rock;
    for (final r in [
      Rect.fromCenter(
        center: Offset(size.width * 0.06, top + size.height * 0.03),
        width: size.width * 0.16,
        height: size.height * 0.1,
      ),
      Rect.fromCenter(
        center: Offset(size.width * 0.93, top + size.height * 0.02),
        width: size.width * 0.14,
        height: size.height * 0.08,
      ),
    ]) {
      canvas.drawOval(r, rock);
      canvas.drawOval(
        Rect.fromLTWH(
          r.left + r.width * 0.2,
          r.top + r.height * 0.12,
          r.width * 0.3,
          r.height * 0.18,
        ),
        Paint()..color = const Color(0x33FFFFFF),
      );
    }
  }

  void _weeds(Canvas canvas, Size size) {
    final rng = math.Random(3);
    final h = size.height;
    final stems = <double>[0.02, 0.09, 0.15, 0.82, 0.88, 0.96, 0.4, 0.62];
    for (var i = 0; i < stems.length; i++) {
      final x = size.width * stems[i];
      final height = h * (0.18 + rng.nextDouble() * 0.2);
      final sway = (i.isEven ? 1 : -1) * size.width * 0.02;
      final path = Path()..moveTo(x, h);
      path.cubicTo(
        x + sway,
        h - height * 0.35,
        x - sway,
        h - height * 0.7,
        x + sway * 0.6,
        h - height,
      );
      final width = math.max(4.0, size.width * 0.008);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width * 1.6
          ..color = i.isEven ? palette.weed : palette.weedLight,
      );
      // Leaves.
      final leaf = Paint()..color = i.isEven ? palette.weedLight : palette.weed;
      for (var k = 1; k < 4; k++) {
        final t = k / 4;
        final y = h - height * t;
        final side = k.isEven ? 1.0 : -1.0;
        canvas.save();
        canvas.translate(x + sway * (t - 0.5), y);
        canvas.rotate(side * 0.7);
        canvas.drawOval(
          Rect.fromLTWH(0, -width * 0.9, width * 4.5 * side, width * 1.8),
          leaf,
        );
        canvas.restore();
      }
    }
  }

  void _corals(Canvas canvas, Size size) {
    final h = size.height;
    final colors = [
      const Color(0xFFFF7EA3),
      const Color(0xFFFFB067),
      const Color(0xFFB58CFF),
    ];
    final spots = [0.12, 0.28, 0.74, 0.9];
    for (var i = 0; i < spots.length; i++) {
      final x = size.width * spots[i];
      final base = h * 0.95;
      final scale = h * 0.12;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(4.0, scale * 0.12)
        ..color = colors[i % colors.length];
      void branch(Offset from, double angle, double len, int depth) {
        final to = from + Offset(math.cos(angle) * len, math.sin(angle) * len);
        canvas.drawLine(from, to, paint);
        if (depth == 0) {
          canvas.drawCircle(
            to,
            paint.strokeWidth * 0.7,
            Paint()..color = paint.color,
          );
          return;
        }
        branch(to, angle - 0.45, len * 0.7, depth - 1);
        branch(to, angle + 0.45, len * 0.7, depth - 1);
      }

      branch(Offset(x, base), -math.pi / 2, scale * 0.6, 2);
    }
  }

  void _ice(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xCCFFFFFF);
    final shade = Paint()..color = const Color(0x66BFE3F5);
    final w = size.width;
    final top = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, size.height * 0.03);
    const n = 9;
    for (var i = n; i >= 0; i--) {
      final x = w * i / n;
      final depth = size.height * (0.03 + 0.05 * (((i * 53) % 7) / 6));
      top.lineTo(x, depth);
    }
    top.close();
    canvas.drawPath(top, paint);
    canvas.drawPath(top.shift(Offset(0, size.height * 0.015)), shade);
  }

  void _moon(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.78, size.height * 0.02);
    final r = size.shortestSide * 0.45;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x55C8D6FF), const Color(0x00C8D6FF)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _bubbles(Canvas canvas, Size size) {
    final rng = math.Random(21);
    final fill = Paint()..color = palette.bubble.withValues(alpha: 0.18);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = palette.bubble;
    final shine = Paint()..color = palette.bubble;
    for (var i = 0; i < 26; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.85;
      final r = 2.0 + rng.nextDouble() * 7;
      canvas.drawCircle(Offset(x, y), r, fill);
      canvas.drawCircle(Offset(x, y), r, rim);
      canvas.drawCircle(Offset(x - r * 0.35, y - r * 0.35), r * 0.25, shine);
    }
  }

  void _glowSpecks(Canvas canvas, Size size) {
    final rng = math.Random(5);
    for (var i = 0; i < 40; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 1.0 + rng.nextDouble() * 1.6;
      canvas.drawCircle(
        Offset(x, y),
        r * 3,
        Paint()..color = const Color(0x1A3FE0C5),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = const Color(0xAA9CFFF0),
      );
    }
  }

  @override
  bool shouldRepaint(SeaSceneryPainter old) => old.palette != palette;
}
