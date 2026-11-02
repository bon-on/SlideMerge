import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One creature of the evolution chain. Tile power p (value `1 << p`) shows
/// [Creature.forPower]; powers above the last entry reuse it.
@immutable
class Creature {
  const Creature._(this.power, this.name, this.bgLight, this.bgDark);

  final int power;
  final String name;

  /// Tile background gradient (center, edge).
  final Color bgLight;
  final Color bgDark;

  int get value => 1 << power;

  /// Whether the tile background is dark (badge and glow switch style).
  bool get darkTile => power >= 14;

  static const List<Creature> all = [
    Creature._(1, 'Plankton', Color(0xFFD9FBE6), Color(0xFF93E4B8)),
    Creature._(2, 'Shrimp', Color(0xFFFFE7EC), Color(0xFFFFB0BF)),
    Creature._(3, 'Starfish', Color(0xFFFFF6C9), Color(0xFFFFD45E)),
    Creature._(4, 'Clownfish', Color(0xFFDDF6FF), Color(0xFF8ED2F2)),
    Creature._(5, 'Pufferfish', Color(0xFFEAF8C0), Color(0xFFB5DD62)),
    Creature._(6, 'Jellyfish', Color(0xFFF0E4FF), Color(0xFFC2A3FF)),
    Creature._(7, 'Crab', Color(0xFFFFF0D6), Color(0xFFFFC27A)),
    Creature._(8, 'Octopus', Color(0xFFD5FAF4), Color(0xFF6FD8CB)),
    Creature._(9, 'Sea Turtle', Color(0xFFFFF0DA), Color(0xFFF0BD7A)),
    Creature._(10, 'Dolphin', Color(0xFFE2E9FF), Color(0xFF98AEFF)),
    Creature._(11, 'Whale', Color(0xFFFFF1A6), Color(0xFFFFB627)),
    Creature._(12, 'Narwhal', Color(0xFFFFE0EE), Color(0xFFFF8EC2)),
    Creature._(13, 'Sea Dragon', Color(0xFFC9F7DD), Color(0xFF2FBF85)),
    Creature._(14, 'Star Whale', Color(0xFF6A5CF0), Color(0xFF1A1360)),
  ];

  static int get maxPower => all.last.power;

  static Creature forPower(int power) => all[(power.clamp(1, maxPower)) - 1];
}

/// Number shown on the tile badge: 2, 64, 2048, 16K for 16384 and above.
String tileValueLabel(int power) {
  final value = 1 << power;
  if (value >= 16384) return '${value ~/ 1024}K';
  return '$value';
}

/// A finished tile: rounded card, creature illustration and a value badge.
class CreatureTile extends StatelessWidget {
  const CreatureTile({
    super.key,
    required this.power,
    this.showBadge = true,
    this.silhouette = false,
  });

  final int power;
  final bool showBadge;

  /// Album entries not discovered yet: a dark shape only.
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: CreatureTilePainter(
          power: power,
          showBadge: showBadge,
          silhouette: silhouette,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints a whole tile into its size. Used by [CreatureTile] and by the
/// effects layer (ghost tiles, pops), so both look identical.
class CreatureTilePainter extends CustomPainter {
  const CreatureTilePainter({
    required this.power,
    this.showBadge = true,
    this.silhouette = false,
    this.card = true,
  });

  final int power;
  final bool showBadge;
  final bool silhouette;

  /// Draw the rounded card behind the creature.
  final bool card;

  @override
  void paint(Canvas canvas, Size size) {
    paintCreatureTile(
      canvas,
      Offset.zero & size,
      power,
      showBadge: showBadge,
      silhouette: silhouette,
      card: card,
    );
  }

  @override
  bool shouldRepaint(CreatureTilePainter old) =>
      old.power != power ||
      old.showBadge != showBadge ||
      old.silhouette != silhouette ||
      old.card != card;
}

const Color _silhouetteInk = Color(0xFF2D4A63);

/// Paints a tile for [power] into [rect].
void paintCreatureTile(
  Canvas canvas,
  Rect rect,
  int power, {
  bool showBadge = true,
  bool silhouette = false,
  bool card = true,
  double opacity = 1,
}) {
  if (rect.width <= 0 || rect.height <= 0) return;
  final creature = Creature.forPower(power);
  final side = math.min(rect.width, rect.height);
  final radius = Radius.circular(side * 0.2);
  final rrect = RRect.fromRectAndRadius(rect, radius);
  if (opacity < 1) {
    canvas.saveLayer(
      rect.inflate(side * 0.1),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );
  }
  if (card) {
    if (silhouette) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0x1F2D4A63));
      canvas.drawRRect(
        rrect.deflate(side * 0.01),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.02
          ..color = const Color(0x55FFFFFF),
      );
    } else {
      // Drop shadow, gradient card, inner rim highlight.
      canvas.drawRRect(
        rrect.shift(Offset(0, side * 0.04)),
        Paint()..color = const Color(0x33052B45),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.45),
            radius: 1.1,
            colors: [creature.bgLight, creature.bgDark],
          ).createShader(rect),
      );
      canvas.drawRRect(
        rrect.deflate(side * 0.025),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.03
          ..color = creature.darkTile
              ? const Color(0x55B9B2FF)
              : const Color(0x88FFFFFF),
      );
    }
  }
  canvas.save();
  // Creature space: 100 x 100, slightly inset so badges do not cover it.
  final inset = showBadge ? 0.88 : 0.96;
  canvas.translate(
    rect.left + (rect.width - side) / 2 + side * (1 - inset) * 0.3,
    rect.top + side * (1 - inset) * 0.25,
  );
  canvas.scale(side * inset / 100);
  if (power > Creature.maxPower && !silhouette) {
    _paintGlow(canvas);
  }
  CreatureDrawer(canvas, silhouette: silhouette).draw(creature.power);
  canvas.restore();
  if (showBadge && !silhouette) {
    _paintBadge(canvas, rect, power, creature);
  }
  if (opacity < 1) canvas.restore();
}

void _paintGlow(Canvas canvas) {
  canvas.drawCircle(
    const Offset(50, 52),
    46,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x88FFE27A), Color(0x00FFE27A)],
      ).createShader(Rect.fromCircle(center: const Offset(50, 52), radius: 46)),
  );
}

void _paintBadge(Canvas canvas, Rect rect, int power, Creature creature) {
  final side = math.min(rect.width, rect.height);
  final label = tileValueLabel(power);
  final fontSize = side * (label.length >= 4 ? 0.15 : 0.17);
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: creature.darkTile
            ? const Color(0xFF1A1360)
            : const Color(0xFF0B3954),
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final padH = side * 0.055;
  final padV = side * 0.03;
  final w = tp.width + padH * 2;
  final h = tp.height + padV * 2;
  final badge = RRect.fromRectAndRadius(
    Rect.fromLTWH(
      rect.right - w - side * 0.05,
      rect.bottom - h - side * 0.05,
      w,
      h,
    ),
    Radius.circular(h / 2),
  );
  canvas.drawRRect(
    badge.shift(Offset(0, side * 0.012)),
    Paint()..color = const Color(0x33052B45),
  );
  canvas.drawRRect(
    badge,
    Paint()
      ..color = creature.darkTile
          ? const Color(0xFFFFE27A)
          : const Color(0xF2FFFFFF),
  );
  tp.paint(canvas, Offset(badge.left + padH, badge.top + padV));
}

/// Draws one creature in a 100 x 100 box centered near (50, 50).
class CreatureDrawer {
  CreatureDrawer(this.canvas, {this.silhouette = false});

  final Canvas canvas;
  final bool silhouette;

  Paint _fill(Color color) =>
      Paint()..color = silhouette ? _silhouetteInk : color;

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = silhouette ? _silhouetteInk : color;

  void draw(int power) {
    switch (power) {
      case 1:
        _plankton();
      case 2:
        _shrimp();
      case 3:
        _starfish();
      case 4:
        _clownfish();
      case 5:
        _pufferfish();
      case 6:
        _jellyfish();
      case 7:
        _crab();
      case 8:
        _octopus();
      case 9:
        _turtle();
      case 10:
        _dolphin();
      case 11:
        _whale(
          body: const Color(0xFF3D7BE0),
          belly: const Color(0xFFBFE3FF),
          spout: true,
        );
      case 12:
        _narwhal();
      case 13:
        _seaDragon();
      default:
        _starWhale();
    }
  }

  // ---------------------------------------------------------------- helpers

  /// Cute eye: white, dark pupil looking slightly forward, two highlights.
  void _eye(Offset c, double r, {Offset look = const Offset(0.15, 0.1)}) {
    if (silhouette) return;
    canvas.drawCircle(c, r, _fill(const Color(0xFFFFFFFF)));
    final pupil = c + Offset(look.dx * r, look.dy * r);
    canvas.drawCircle(pupil, r * 0.68, _fill(const Color(0xFF14233A)));
    canvas.drawCircle(
      pupil + Offset(-r * 0.25, -r * 0.28),
      r * 0.26,
      _fill(const Color(0xFFFFFFFF)),
    );
    canvas.drawCircle(
      pupil + Offset(r * 0.22, r * 0.22),
      r * 0.11,
      _fill(const Color(0xCCFFFFFF)),
    );
  }

  /// Dot eye for small creatures.
  void _dotEye(Offset c, double r) {
    if (silhouette) return;
    canvas.drawCircle(c, r, _fill(const Color(0xFF14233A)));
    canvas.drawCircle(
      c + Offset(-r * 0.35, -r * 0.35),
      r * 0.38,
      _fill(const Color(0xFFFFFFFF)),
    );
  }

  void _smile(Offset c, double w, {double width = 2.2}) {
    if (silhouette) return;
    final path = Path()
      ..moveTo(c.dx - w / 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + w * 0.55, c.dx + w / 2, c.dy);
    canvas.drawPath(path, _stroke(const Color(0xFF14233A), width));
  }

  void _blush(Offset c, double r) {
    if (silhouette) return;
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 2, height: r * 1.2),
      _fill(const Color(0x66FF6F91)),
    );
  }

  void _shine(Rect oval) {
    if (silhouette) return;
    canvas.drawOval(oval, _fill(const Color(0x66FFFFFF)));
  }

  void _shadow(double cx, double y, double w) {
    if (silhouette) return;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, y), width: w, height: w * 0.18),
      _fill(const Color(0x22052B45)),
    );
  }

  // -------------------------------------------------------------- creatures

  void _plankton() {
    _shadow(50, 82, 44);
    final body = _fill(const Color(0xFF4CC98A));
    // Cilia ring.
    final cilia = _stroke(const Color(0xFF2FA56B), 2.4);
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi * 2 / 14;
      final p1 = Offset(50 + math.cos(a) * 23, 52 + math.sin(a) * 23);
      final p2 = Offset(50 + math.cos(a) * 30, 52 + math.sin(a) * 30);
      canvas.drawLine(p1, p2, cilia);
    }
    canvas.drawCircle(const Offset(50, 52), 24, body);
    canvas.drawCircle(const Offset(50, 52), 18, _fill(const Color(0xFF7DE3AE)));
    // Organelles.
    canvas.drawCircle(
      const Offset(58, 63),
      3.2,
      _fill(const Color(0xFF3BB37A)),
    );
    canvas.drawCircle(
      const Offset(41, 63),
      2.2,
      _fill(const Color(0xFF3BB37A)),
    );
    canvas.drawCircle(
      const Offset(62, 42),
      1.8,
      _fill(const Color(0xFF3BB37A)),
    );
    _shine(const Rect.fromLTWH(36, 34, 12, 7));
    _dotEye(const Offset(43, 51), 3.6);
    _dotEye(const Offset(57, 51), 3.6);
    _smile(const Offset(50, 57), 7, width: 1.8);
    _blush(const Offset(38, 57), 3.4);
    _blush(const Offset(62, 57), 3.4);
  }

  void _shrimp() {
    _shadow(52, 84, 54);
    const color = Color(0xFFFF7A8A);
    const dark = Color(0xFFE2526A);
    // Antennae.
    final ant = _stroke(dark, 1.8);
    canvas.drawPath(
      Path()
        ..moveTo(66, 34)
        ..quadraticBezierTo(80, 14, 92, 20),
      ant,
    );
    canvas.drawPath(
      Path()
        ..moveTo(62, 33)
        ..quadraticBezierTo(70, 10, 84, 10),
      ant,
    );
    // Tail fan.
    final tail = Path()
      ..moveTo(28, 68)
      ..lineTo(14, 62)
      ..quadraticBezierTo(12, 72, 18, 80)
      ..close();
    canvas.drawPath(tail, _fill(dark));
    final tail2 = Path()
      ..moveTo(28, 68)
      ..lineTo(20, 84)
      ..quadraticBezierTo(30, 88, 36, 80)
      ..close();
    canvas.drawPath(tail2, _fill(dark));
    // Curled segmented body: circles along an arc, big head at the front.
    const segments = 6;
    for (var i = 0; i < segments; i++) {
      final t = i / (segments - 1);
      final a = math.pi * (0.85 - 1.05 * t);
      final r = 13.0 + 7.0 * t;
      final c = Offset(50 + math.cos(a) * 18, 54 + math.sin(a) * 18 * 0.9);
      canvas.drawCircle(c, r * 0.72 + 2, _fill(i.isEven ? color : dark));
      canvas.drawCircle(c, r * 0.72, _fill(color));
    }
    // Legs.
    final legs = _stroke(dark, 2);
    for (var i = 0; i < 3; i++) {
      final x = 44.0 + i * 7;
      canvas.drawLine(Offset(x, 66), Offset(x - 3, 76), legs);
    }
    // Head.
    canvas.drawCircle(const Offset(64, 44), 15, _fill(color));
    _shine(const Rect.fromLTWH(54, 33, 10, 6));
    _eye(const Offset(67, 41), 5.2, look: const Offset(0.25, 0));
    _smile(const Offset(68, 50), 6, width: 1.8);
    _blush(const Offset(59, 50), 3.4);
  }

  void _starfish() {
    _shadow(50, 86, 60);
    final path = Path();
    const cx = 50.0, cy = 52.0;
    const outer = 36.0, inner = 17.0;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final b = a + math.pi / 5;
      final tip = Offset(cx + math.cos(a) * outer, cy + math.sin(a) * outer);
      final valley = Offset(cx + math.cos(b) * inner, cy + math.sin(b) * inner);
      final before = a - math.pi / 5;
      final prev = Offset(
        cx + math.cos(before) * inner,
        cy + math.sin(before) * inner,
      );
      if (i == 0) path.moveTo(prev.dx, prev.dy);
      // Rounded tip: control points slightly to either side of the tip.
      final ctrl1 = Offset(
        cx + math.cos(a - 0.12) * (outer + 3),
        cy + math.sin(a - 0.12) * (outer + 3),
      );
      final ctrl2 = Offset(
        cx + math.cos(a + 0.12) * (outer + 3),
        cy + math.sin(a + 0.12) * (outer + 3),
      );
      path.quadraticBezierTo(
        (prev.dx + ctrl1.dx) / 2,
        (prev.dy + ctrl1.dy) / 2,
        ctrl1.dx,
        ctrl1.dy,
      );
      path.quadraticBezierTo(tip.dx, tip.dy, ctrl2.dx, ctrl2.dy);
      path.quadraticBezierTo(
        (ctrl2.dx + valley.dx) / 2,
        (ctrl2.dy + valley.dy) / 2,
        valley.dx,
        valley.dy,
      );
    }
    path.close();
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      _fill(const Color(0xFFE0782E)),
    );
    canvas.drawPath(path, _fill(const Color(0xFFFF9F45)));
    // Texture dots along each arm.
    final dot = _fill(const Color(0xFFFFD08A));
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      for (final d in const [20.0, 28.0]) {
        canvas.drawCircle(
          Offset(cx + math.cos(a) * d, cy + math.sin(a) * d),
          d > 25 ? 1.8 : 2.4,
          dot,
        );
      }
    }
    _shine(const Rect.fromLTWH(40, 30, 9, 6));
    _eye(const Offset(43, 50), 4.6);
    _eye(const Offset(57, 50), 4.6);
    _smile(const Offset(50, 58), 8);
    _blush(const Offset(37, 58), 3.6);
    _blush(const Offset(63, 58), 3.6);
  }

  void _clownfish() {
    _shadow(50, 84, 56);
    const orange = Color(0xFFFF7A1A);
    const dark = Color(0xFF1E2A3A);
    final bodyRect = Rect.fromCenter(
      center: const Offset(52, 52),
      width: 58,
      height: 40,
    );
    // Tail.
    final tail = Path()
      ..moveTo(28, 52)
      ..lineTo(12, 38)
      ..quadraticBezierTo(8, 52, 12, 66)
      ..close();
    canvas.drawPath(tail, _fill(orange));
    canvas.drawPath(tail, _stroke(dark, 2.2));
    // Fins.
    final top = Path()
      ..moveTo(40, 36)
      ..quadraticBezierTo(50, 20, 64, 34)
      ..close();
    canvas.drawPath(top, _fill(orange));
    canvas.drawPath(top, _stroke(dark, 2.2));
    final body = Path()..addOval(bodyRect);
    canvas.drawPath(body, _fill(orange));
    // White stripes clipped to the body.
    canvas.save();
    canvas.clipPath(body);
    final white = _fill(const Color(0xFFFFFFFF));
    final rim = _stroke(dark, 2.2);
    for (final x in const [38.0, 58.0]) {
      final stripe = Rect.fromCenter(
        center: Offset(x, 52),
        width: 9,
        height: 50,
      );
      final rr = RRect.fromRectAndRadius(stripe, const Radius.circular(5));
      canvas.drawRRect(rr, white);
      canvas.drawRRect(rr, rim);
    }
    canvas.restore();
    canvas.drawPath(body, _stroke(dark, 2.2));
    // Side fin.
    final side = Path()
      ..moveTo(50, 60)
      ..quadraticBezierTo(44, 70, 52, 72)
      ..quadraticBezierTo(56, 66, 50, 60);
    canvas.drawPath(side, _fill(const Color(0xFFFF9A4A)));
    _shine(const Rect.fromLTWH(44, 36, 14, 6));
    _eye(const Offset(70, 48), 5.6, look: const Offset(0.3, 0.05));
    _smile(const Offset(73, 58), 6, width: 1.8);
    _blush(const Offset(66, 58), 3);
  }

  void _pufferfish() {
    _shadow(50, 86, 58);
    const body = Color(0xFFFFCC33);
    const spike = Color(0xFFE29A12);
    final spikes = _fill(spike);
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi * 2 / 14 + 0.1;
      final base1 = Offset(
        50 + math.cos(a - 0.14) * 25,
        52 + math.sin(a - 0.14) * 25,
      );
      final base2 = Offset(
        50 + math.cos(a + 0.14) * 25,
        52 + math.sin(a + 0.14) * 25,
      );
      final tip = Offset(50 + math.cos(a) * 34, 52 + math.sin(a) * 34);
      canvas.drawPath(
        Path()
          ..moveTo(base1.dx, base1.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(base2.dx, base2.dy)
          ..close(),
        spikes,
      );
    }
    // Tail and fins.
    canvas.drawPath(
      Path()
        ..moveTo(22, 52)
        ..lineTo(10, 44)
        ..lineTo(12, 60)
        ..close(),
      _fill(spike),
    );
    canvas.drawCircle(const Offset(50, 52), 27, _fill(body));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(52, 62), width: 40, height: 22),
      _fill(const Color(0xFFFFF0B3)),
    );
    // Freckles.
    final freckle = _fill(const Color(0xFFE8A92A));
    for (final o in const [
      Offset(40, 36),
      Offset(48, 32),
      Offset(58, 34),
      Offset(36, 44),
    ]) {
      canvas.drawCircle(o, 1.6, freckle);
    }
    _shine(const Rect.fromLTWH(36, 30, 12, 7));
    _eye(const Offset(42, 48), 6);
    _eye(const Offset(60, 48), 6);
    // Puckered "o" mouth.
    if (!silhouette) {
      canvas.drawCircle(
        const Offset(51, 61),
        3.2,
        _fill(const Color(0xFFFF7A6B)),
      );
      canvas.drawCircle(
        const Offset(51, 61),
        3.2,
        _stroke(const Color(0xFF14233A), 1.6),
      );
    }
    _blush(const Offset(35, 58), 3.6);
    _blush(const Offset(67, 58), 3.6);
  }

  void _jellyfish() {
    const bell = Color(0xFFB57BFF);
    const light = Color(0xFFE1C8FF);
    // Tentacles first (behind the bell).
    for (var i = 0; i < 5; i++) {
      final x = 30.0 + i * 10;
      final wobble = i.isEven ? 5.0 : -5.0;
      final path = Path()
        ..moveTo(x, 54)
        ..cubicTo(x + wobble, 64, x - wobble, 74, x + wobble * 0.6, 88);
      canvas.drawPath(path, _stroke(const Color(0xFF9B5CF0), 3.4));
    }
    // Frilly inner arms.
    canvas.drawPath(
      Path()
        ..moveTo(44, 54)
        ..quadraticBezierTo(40, 68, 46, 78)
        ..quadraticBezierTo(50, 68, 50, 54),
      _fill(const Color(0xFFD9B8FF)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(56, 54)
        ..quadraticBezierTo(60, 68, 54, 78)
        ..quadraticBezierTo(50, 68, 50, 54),
      _fill(const Color(0xFFD9B8FF)),
    );
    // Bell with a scalloped rim.
    final dome = Path()
      ..moveTo(20, 56)
      ..cubicTo(18, 22, 82, 22, 80, 56);
    const scallops = 6;
    for (var i = scallops; i > 0; i--) {
      final x1 = 20 + (i - 1) * 60 / scallops;
      final xm = 20 + (i - 0.5) * 60 / scallops;
      dome.quadraticBezierTo(xm, 64, x1, 56);
    }
    dome.close();
    canvas.drawPath(dome, _fill(bell));
    canvas.drawPath(
      Path()
        ..moveTo(28, 52)
        ..cubicTo(28, 32, 72, 32, 72, 52)
        ..close(),
      _fill(const Color(0x33FFFFFF)),
    );
    // Spots.
    final spot = _fill(light);
    canvas.drawCircle(const Offset(36, 36), 3, spot);
    canvas.drawCircle(const Offset(66, 38), 2.4, spot);
    canvas.drawCircle(const Offset(58, 30), 1.8, spot);
    _shine(const Rect.fromLTWH(32, 28, 14, 7));
    _eye(const Offset(42, 46), 4.8);
    _eye(const Offset(58, 46), 4.8);
    _smile(const Offset(50, 53), 7, width: 1.8);
    _blush(const Offset(35, 52), 3.2);
    _blush(const Offset(65, 52), 3.2);
  }

  void _crab() {
    _shadow(50, 86, 66);
    const red = Color(0xFFF2453D);
    const dark = Color(0xFFC22D2D);
    // Legs.
    final leg = _stroke(dark, 3.4);
    for (var i = 0; i < 3; i++) {
      final y = 60.0 + i * 6;
      canvas.drawPath(
        Path()
          ..moveTo(30, y)
          ..quadraticBezierTo(18, y + 2, 14, y + 10),
        leg,
      );
      canvas.drawPath(
        Path()
          ..moveTo(70, y)
          ..quadraticBezierTo(82, y + 2, 86, y + 10),
        leg,
      );
    }
    // Arms and claws.
    final arm = _stroke(red, 5);
    canvas.drawPath(
      Path()
        ..moveTo(32, 54)
        ..quadraticBezierTo(18, 48, 20, 36),
      arm,
    );
    canvas.drawPath(
      Path()
        ..moveTo(68, 54)
        ..quadraticBezierTo(82, 48, 80, 36),
      arm,
    );
    for (final c in const [Offset(20, 30), Offset(80, 30)]) {
      canvas.drawCircle(c, 10, _fill(red));
      // Notch of the pincer.
      if (!silhouette) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 1)
            ..lineTo(c.dx - 3, c.dy - 10)
            ..lineTo(c.dx + 3, c.dy - 10)
            ..close(),
          _fill(dark),
        );
      }
      _shine(Rect.fromLTWH(c.dx - 7, c.dy - 2, 5, 4));
    }
    // Eye stalks.
    final stalk = _stroke(dark, 3);
    canvas.drawLine(const Offset(42, 46), const Offset(40, 32), stalk);
    canvas.drawLine(const Offset(58, 46), const Offset(60, 32), stalk);
    // Body.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 60), width: 50, height: 32),
      _fill(red),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 66), width: 36, height: 14),
      _fill(const Color(0xFFFF7A6B)),
    );
    _shine(const Rect.fromLTWH(36, 48, 14, 6));
    _eye(const Offset(40, 30), 5.4, look: const Offset(0, 0.15));
    _eye(const Offset(60, 30), 5.4, look: const Offset(0, 0.15));
    _smile(const Offset(50, 60), 9);
    _blush(const Offset(37, 62), 3.4);
    _blush(const Offset(63, 62), 3.4);
  }

  void _octopus() {
    _shadow(50, 88, 62);
    const pink = Color(0xFFE94BA0);
    const dark = Color(0xFFC0337F);
    // Tentacles: thick curling strokes.
    final arms = <Path>[
      Path()
        ..moveTo(34, 56)
        ..cubicTo(22, 64, 18, 78, 28, 84),
      Path()
        ..moveTo(42, 60)
        ..cubicTo(36, 72, 36, 82, 44, 86),
      Path()
        ..moveTo(58, 60)
        ..cubicTo(64, 72, 64, 82, 56, 86),
      Path()
        ..moveTo(66, 56)
        ..cubicTo(78, 64, 82, 78, 72, 84),
    ];
    for (final p in arms) {
      canvas.drawPath(p, _stroke(dark, 10));
      canvas.drawPath(p, _stroke(pink, 7.5));
    }
    // Suckers.
    if (!silhouette) {
      final sucker = _fill(const Color(0xFFFFC1DE));
      for (final o in const [
        Offset(25, 74),
        Offset(38, 76),
        Offset(62, 76),
        Offset(75, 74),
      ]) {
        canvas.drawCircle(o, 1.8, sucker);
      }
    }
    // Head.
    final head = Path()
      ..moveTo(26, 56)
      ..cubicTo(20, 18, 80, 18, 74, 56)
      ..quadraticBezierTo(50, 66, 26, 56)
      ..close();
    canvas.drawPath(head, _fill(pink));
    final spot = _fill(const Color(0xFFF47CBC));
    canvas.drawCircle(const Offset(62, 30), 3.4, spot);
    canvas.drawCircle(const Offset(68, 40), 2.2, spot);
    canvas.drawCircle(const Offset(36, 32), 2.2, spot);
    _shine(const Rect.fromLTWH(34, 26, 14, 8));
    _eye(const Offset(41, 44), 5.6);
    _eye(const Offset(59, 44), 5.6);
    _smile(const Offset(50, 52), 8);
    _blush(const Offset(33, 52), 3.6);
    _blush(const Offset(67, 52), 3.6);
  }

  void _turtle() {
    _shadow(50, 86, 66);
    const skin = Color(0xFF8FD16A);
    const skinDark = Color(0xFF5FAE45);
    const shell = Color(0xFF2E9E6B);
    // Flippers.
    for (final r in [
      Rect.fromCenter(center: const Offset(30, 40), width: 22, height: 12),
      Rect.fromCenter(center: const Offset(66, 40), width: 22, height: 12),
      Rect.fromCenter(center: const Offset(30, 70), width: 18, height: 10),
      Rect.fromCenter(center: const Offset(64, 72), width: 18, height: 10),
    ]) {
      canvas.drawOval(r, _fill(skinDark));
    }
    // Head.
    canvas.drawCircle(const Offset(78, 52), 13, _fill(skin));
    // Shell.
    final shellRect = Rect.fromCenter(
      center: const Offset(46, 55),
      width: 58,
      height: 42,
    );
    canvas.drawOval(shellRect.inflate(3), _fill(const Color(0xFFE8D27A)));
    canvas.drawOval(shellRect, _fill(shell));
    // Plates.
    final plate = _fill(const Color(0xFF4CBF85));
    final center = Path();
    const pc = Offset(46, 54);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final p = Offset(pc.dx + math.cos(a) * 10, pc.dy + math.sin(a) * 8);
      i == 0 ? center.moveTo(p.dx, p.dy) : center.lineTo(p.dx, p.dy);
    }
    center.close();
    canvas.drawPath(center, plate);
    for (final o in const [
      Offset(30, 50),
      Offset(62, 50),
      Offset(38, 66),
      Offset(55, 67),
      Offset(46, 39),
    ]) {
      canvas.drawCircle(o, 5.2, plate);
    }
    _shine(const Rect.fromLTWH(26, 38, 16, 7));
    _eye(const Offset(81, 49), 4.4, look: const Offset(0.3, 0));
    _smile(const Offset(82, 57), 6, width: 1.8);
    _blush(const Offset(75, 57), 2.6);
  }

  void _dolphin() {
    _shadow(50, 86, 60);
    const blue = Color(0xFF4F8DF5);
    const belly = Color(0xFFD2E4FF);
    // Tail flukes.
    canvas.drawPath(
      Path()
        ..moveTo(20, 62)
        ..quadraticBezierTo(6, 54, 4, 64)
        ..quadraticBezierTo(12, 66, 16, 70)
        ..quadraticBezierTo(10, 78, 18, 82)
        ..quadraticBezierTo(22, 72, 26, 66)
        ..close(),
      _fill(const Color(0xFF3B74D9)),
    );
    // Dorsal fin.
    canvas.drawPath(
      Path()
        ..moveTo(42, 38)
        ..quadraticBezierTo(44, 22, 56, 20)
        ..quadraticBezierTo(52, 30, 58, 38)
        ..close(),
      _fill(const Color(0xFF3B74D9)),
    );
    // Body arc.
    final body = Path()
      ..moveTo(22, 66)
      ..cubicTo(28, 40, 58, 30, 78, 44)
      ..quadraticBezierTo(90, 50, 94, 54)
      ..quadraticBezierTo(90, 58, 80, 58)
      ..cubicTo(64, 66, 44, 70, 22, 66)
      ..close();
    canvas.drawPath(body, _fill(blue));
    final bellyPath = Path()
      ..moveTo(30, 66)
      ..cubicTo(46, 70, 66, 64, 82, 57)
      ..quadraticBezierTo(70, 54, 60, 58)
      ..cubicTo(50, 62, 40, 64, 30, 66)
      ..close();
    canvas.drawPath(bellyPath, _fill(belly));
    // Flipper.
    canvas.drawPath(
      Path()
        ..moveTo(54, 60)
        ..quadraticBezierTo(50, 72, 42, 74)
        ..quadraticBezierTo(48, 64, 48, 60)
        ..close(),
      _fill(const Color(0xFF3B74D9)),
    );
    _shine(const Rect.fromLTWH(44, 38, 18, 6));
    _eye(const Offset(74, 47), 4.6, look: const Offset(0.3, 0));
    _smile(const Offset(86, 56), 6, width: 1.6);
    _blush(const Offset(72, 54), 3);
  }

  void _whale({
    required Color body,
    required Color belly,
    bool spout = false,
    bool spots = false,
  }) {
    _shadow(52, 88, 70);
    final darker = Color.lerp(body, const Color(0xFF000000), 0.18)!;
    if (spout && !silhouette) {
      final water = _fill(const Color(0xFF8FD3FF));
      canvas.drawPath(
        Path()
          ..moveTo(58, 34)
          ..quadraticBezierTo(54, 20, 44, 16)
          ..quadraticBezierTo(54, 18, 58, 10)
          ..quadraticBezierTo(62, 18, 72, 16)
          ..quadraticBezierTo(62, 20, 60, 34)
          ..close(),
        water,
      );
      canvas.drawCircle(const Offset(42, 12), 2.4, water);
      canvas.drawCircle(const Offset(74, 12), 2.4, water);
      canvas.drawCircle(const Offset(58, 6), 2, water);
    }
    // Tail rising on the left.
    canvas.drawPath(
      Path()
        ..moveTo(24, 62)
        ..quadraticBezierTo(14, 52, 12, 40)
        ..quadraticBezierTo(4, 36, 2, 30)
        ..quadraticBezierTo(12, 30, 16, 36)
        ..quadraticBezierTo(18, 28, 26, 26)
        ..quadraticBezierTo(22, 38, 30, 54)
        ..close(),
      _fill(darker),
    );
    final bodyRect = Rect.fromCenter(
      center: const Offset(56, 60),
      width: 70,
      height: 46,
    );
    canvas.drawOval(bodyRect, _fill(body));
    // Belly with grooves.
    canvas.save();
    canvas.clipPath(Path()..addOval(bodyRect));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(62, 82), width: 66, height: 34),
      _fill(belly),
    );
    if (!silhouette) {
      final groove = _stroke(Color.lerp(belly, body, 0.35)!, 1.4);
      for (var i = 0; i < 3; i++) {
        final y = 72.0 + i * 4;
        canvas.drawLine(Offset(48, y), Offset(84, y - 2), groove);
      }
    }
    canvas.restore();
    if (spots && !silhouette) {
      final spot = _fill(Color.lerp(body, const Color(0xFFFFFFFF), 0.35)!);
      for (final o in const [
        Offset(40, 50),
        Offset(50, 44),
        Offset(36, 60),
        Offset(46, 56),
        Offset(60, 46),
      ]) {
        canvas.drawCircle(o, 2.2, spot);
      }
    }
    // Flipper.
    canvas.drawPath(
      Path()
        ..moveTo(48, 68)
        ..quadraticBezierTo(42, 80, 32, 80)
        ..quadraticBezierTo(38, 70, 42, 66)
        ..close(),
      _fill(darker),
    );
    _shine(const Rect.fromLTWH(40, 42, 20, 8));
    _eye(const Offset(74, 56), 5, look: const Offset(0.2, 0));
    _smile(const Offset(80, 66), 8);
    _blush(const Offset(70, 66), 3.6);
  }

  void _narwhal() {
    // Spiral tusk first (sticks out to the upper right).
    final tusk = Path()
      ..moveTo(76, 50)
      ..lineTo(98, 12)
      ..lineTo(84, 54)
      ..close();
    canvas.drawPath(tusk, _fill(const Color(0xFFFFF8E1)));
    canvas.drawPath(tusk, _stroke(const Color(0xFFC9AE72), 1.4));
    if (!silhouette) {
      final ridge = _stroke(const Color(0xFFC9AE72), 1.4);
      for (var i = 0; i < 6; i++) {
        final t = 0.12 + i * 0.14;
        final x = 80 + (98 - 80) * t;
        final y = 52 + (12 - 52) * t;
        final half = 3.2 * (1 - t);
        canvas.drawLine(
          Offset(x - half, y - half * 0.4),
          Offset(x + half, y + half * 0.6),
          ridge,
        );
      }
    }
    _whale(
      body: const Color(0xFF7C93C9),
      belly: const Color(0xFFE6EEFF),
      spots: true,
    );
  }

  void _seaDragon() {
    _shadow(50, 88, 60);
    const green = Color(0xFF1FA67A);
    const gold = Color(0xFFFFC94A);
    // Serpentine body: thick S-curve with a gold underline.
    final body = Path()
      ..moveTo(62, 34)
      ..cubicTo(40, 36, 30, 52, 46, 60)
      ..cubicTo(62, 68, 60, 84, 36, 84)
      ..quadraticBezierTo(26, 84, 22, 78);
    canvas.drawPath(body, _stroke(const Color(0xFF137A59), 17));
    canvas.drawPath(body, _stroke(green, 13));
    if (!silhouette) {
      canvas.drawPath(body.shift(const Offset(2, 3)), _stroke(gold, 3));
    }
    // Leafy fins along the back.
    final leaf = _fill(const Color(0xFF7BE0A8));
    for (final p in const [
      (Offset(40, 42), -0.9),
      (Offset(36, 56), -2.2),
      (Offset(58, 70), 0.6),
      (Offset(48, 82), 1.6),
    ]) {
      canvas.save();
      canvas.translate(p.$1.dx, p.$1.dy);
      canvas.rotate(p.$2);
      canvas.drawOval(const Rect.fromLTWH(0, -4, 14, 8), leaf);
      canvas.restore();
    }
    // Head with horns and snout.
    canvas.drawPath(
      Path()
        ..moveTo(60, 24)
        ..lineTo(56, 10)
        ..lineTo(66, 22)
        ..close(),
      _fill(gold),
    );
    canvas.drawPath(
      Path()
        ..moveTo(70, 24)
        ..lineTo(74, 10)
        ..lineTo(76, 26)
        ..close(),
      _fill(gold),
    );
    canvas.drawCircle(const Offset(68, 34), 14, _fill(green));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(82, 38), width: 18, height: 12),
      _fill(green),
    );
    canvas.drawCircle(
      const Offset(86, 36),
      1.4,
      _fill(const Color(0xFF0E5A42)),
    );
    _shine(const Rect.fromLTWH(60, 24, 10, 5));
    _eye(const Offset(70, 32), 5, look: const Offset(0.3, 0));
    _smile(const Offset(80, 42), 6, width: 1.6);
    _blush(const Offset(64, 41), 3);
  }

  void _starWhale() {
    _whale(body: const Color(0xFF6C5CFF), belly: const Color(0xFFC9C0FF));
    if (silhouette) return;
    // Constellation on the back and a star on the forehead.
    final star = _fill(const Color(0xFFFFE27A));
    final line = _stroke(const Color(0x99FFE27A), 1);
    const pts = [
      Offset(36, 52),
      Offset(46, 46),
      Offset(56, 50),
      Offset(62, 44),
    ];
    for (var i = 0; i + 1 < pts.length; i++) {
      canvas.drawLine(pts[i], pts[i + 1], line);
    }
    for (final p in pts) {
      canvas.drawCircle(p, 1.8, star);
    }
    _star(const Offset(66, 40), 6, star);
    for (final p in const [Offset(14, 16), Offset(88, 22), Offset(30, 10)]) {
      _star(p, 3.4, _fill(const Color(0xFFFFF4C2)));
    }
  }

  void _star(Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final d = i.isEven ? r : r * 0.38;
      final p = Offset(c.dx + math.cos(a) * d, c.dy + math.sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}
