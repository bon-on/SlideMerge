import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game_logic.dart';
import '../art/creature_art.dart';

/// Effect durations. Rules apply instantly; effects trail behind.
class FxTiming {
  /// Tile travel (also the `AnimatedPositioned` duration).
  static const Duration slide = Duration(milliseconds: 110);
  static const Duration pop = Duration(milliseconds: 230);
  static const Duration spawn = Duration(milliseconds: 190);
  static const Duration burst = Duration(milliseconds: 650);
  static const Duration popup = Duration(milliseconds: 850);
  static const Duration banner = Duration(milliseconds: 1500);
  static const Duration bigBanner = Duration(milliseconds: 2400);
  static const Duration celebrate = Duration(milliseconds: 1700);
  static const Duration dangerPulse = Duration(milliseconds: 1300);
}

enum BannerStyle { combo, discover, mission, record, info }

abstract class _Event {
  _Event(this.start, this.seed);

  final Duration start;
  final int seed;
  Duration get length;
}

class _Ghost extends _Event {
  _Ghost(super.start, super.seed, this.power, this.from, this.to);
  final int power;
  final int from;
  final int to;
  @override
  Duration get length => FxTiming.slide + const Duration(milliseconds: 40);
}

class _Pop extends _Event {
  _Pop(super.start, super.seed, this.tileId, this.oldPower);
  final int tileId;
  final int oldPower;
  @override
  Duration get length => FxTiming.slide + FxTiming.pop;
}

class _Spawn extends _Event {
  _Spawn(super.start, super.seed, this.tileId);
  final int tileId;
  @override
  Duration get length => FxTiming.slide + FxTiming.spawn;
}

class _Burst extends _Event {
  _Burst(super.start, super.seed, this.index, this.color, this.count);
  final int index;
  final Color color;
  final int count;
  @override
  Duration get length => FxTiming.slide + FxTiming.burst;
}

class _Popup extends _Event {
  _Popup(super.start, super.seed, this.index, this.text);
  final int index;
  final String text;
  @override
  Duration get length => FxTiming.slide + FxTiming.popup;
}

class _Celebrate extends _Event {
  _Celebrate(super.start, super.seed, this.index, this.big);
  final int index;
  final bool big;
  @override
  Duration get length => FxTiming.slide + FxTiming.celebrate;
}

class _Danger extends _Event {
  _Danger(super.start, super.seed);
  @override
  Duration get length => FxTiming.dangerPulse;
}

/// A banner currently on screen.
class FxBanner extends _Event {
  FxBanner(
    super.start,
    super.seed,
    this.title,
    this.subtitle,
    this.style,
    this.power,
  );

  final String title;
  final String? subtitle;
  final BannerStyle style;

  /// Creature shown next to the text, if any.
  final int? power;

  @override
  Duration get length =>
      style == BannerStyle.discover ? FxTiming.bigBanner : FxTiming.banner;
}

/// Queue of board effects with its own clock.
///
/// One [Ticker] (from [attach]) drives everything; it runs only while an
/// effect is alive. The clock belongs to the queue, not to the widget, so a
/// board that is rebuilt (layout switch) continues the same timeline.
class BoardFx extends ChangeNotifier {
  final List<_Event> _events = <_Event>[];
  Duration _clock = Duration.zero;
  Duration _base = Duration.zero;
  Ticker? _ticker;
  int _seed = 1;

  bool _danger = false;

  /// Few empty cells left: the board shows a red rim.
  bool get danger => _danger;
  set danger(bool value) {
    if (value == _danger) return;
    _danger = value;
    notifyListeners();
  }

  Duration get clock => _clock;

  bool get isActive => _events.isNotEmpty;

  Object? _owner;

  /// The newest board view drives the clock. A view that is replaced (layout
  /// switch) may detach after its successor attached; that must not stop
  /// the successor's ticker.
  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _owner = vsync;
    _ticker = vsync.createTicker(_onTick);
    _syncTicker();
  }

  void detach(TickerProvider vsync) {
    if (!identical(_owner, vsync)) return;
    _ticker?.dispose();
    _ticker = null;
    _owner = null;
  }

  void _onTick(Duration elapsed) {
    _clock = _base + elapsed;
    _events.removeWhere((e) => _clock - e.start > e.length);
    if (_events.isEmpty) _ticker?.stop();
    notifyListeners();
  }

  void _add(_Event event) {
    _events.add(event);
    _syncTicker();
  }

  void _syncTicker() {
    final ticker = _ticker;
    if (ticker == null) {
      notifyListeners();
      return;
    }
    if (_events.isNotEmpty && !ticker.isActive) {
      _base = _clock;
      ticker.start();
    }
    notifyListeners();
  }

  int _nextSeed() => _seed++;

  /// Effects for one successful move.
  void onMove(MoveReport report, List<Tile?> cells) {
    for (final m in report.merges) {
      _add(_Ghost(_clock, _nextSeed(), m.power - 1, m.consumedFrom, m.target));
      _add(_Pop(_clock, _nextSeed(), m.keptId, m.power - 1));
      _add(
        _Burst(
          _clock,
          _nextSeed(),
          m.target,
          Creature.forPower(m.power).bgDark,
          6 + math.min(10, m.power),
        ),
      );
      _add(_Popup(_clock, _nextSeed(), m.target, '+${1 << m.power}'));
    }
    final spawned = report.spawnedId;
    if (spawned != null) _add(_Spawn(_clock, _nextSeed(), spawned));
  }

  void banner(
    String title, {
    String? subtitle,
    BannerStyle style = BannerStyle.info,
    int? power,
  }) {
    // Keep at most two banners: the newest replaces the oldest.
    final banners = _events.whereType<FxBanner>().toList();
    if (banners.length >= 2) _events.remove(banners.first);
    _add(FxBanner(_clock, _nextSeed(), title, subtitle, style, power));
  }

  /// Bubble fireworks around [index]; [big] fills the whole board.
  void celebrate(int index, {bool big = false}) =>
      _add(_Celebrate(_clock, _nextSeed(), index, big));

  void pulseDanger() {
    _events.removeWhere((e) => e is _Danger);
    _add(_Danger(_clock, _nextSeed()));
  }

  /// Drops every effect (restart, undo, mode switch).
  void clear() {
    _events.clear();
    notifyListeners();
  }

  Duration _age(_Event e) => _clock - e.start;

  double _f(Duration t, Duration from, Duration length) {
    final v = (t - from).inMicroseconds / length.inMicroseconds;
    return v.clamp(0.0, 1.0);
  }

  /// Scale of a real tile right now (pop after a merge, grow after a spawn).
  double tileScale(int tileId) {
    for (final e in _events) {
      if (e is _Pop && e.tileId == tileId) {
        final f = _f(_age(e), FxTiming.slide, FxTiming.pop);
        if (f <= 0) return 1;
        return 1 + 0.22 * math.sin(math.pi * f);
      }
      if (e is _Spawn && e.tileId == tileId) {
        final f = _f(_age(e), FxTiming.slide, FxTiming.spawn);
        if (f <= 0) return 0;
        return Curves.easeOutBack.transform(f);
      }
    }
    return 1;
  }

  /// Power a merged tile still shows while it travels (the old creature).
  int? shownPower(int tileId) {
    for (final e in _events) {
      if (e is _Pop && e.tileId == tileId && _age(e) < FxTiming.slide) {
        return e.oldPower;
      }
    }
    return null;
  }

  List<FxBanner> get banners => _events.whereType<FxBanner>().toList();

  /// 0..1 progress of [banner].
  double bannerProgress(FxBanner banner) =>
      _f(_age(banner), Duration.zero, banner.length);

  /// Strength of the danger rim pulse, 0..1.
  double get dangerPulse {
    for (final e in _events) {
      if (e is _Danger) {
        final f = _f(_age(e), Duration.zero, e.length);
        return math.sin(f * math.pi * 3).abs() * (1 - f);
      }
    }
    return 0;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// Board geometry shared by tiles and effect painters.
class BoardGeometry {
  const BoardGeometry({required this.boardSize, required this.size});

  final double boardSize;
  final int size;

  double get padding => boardSize * 0.03;
  double get gap => boardSize * (size >= 5 ? 0.018 : 0.022);
  double get tile => (boardSize - padding * 2 - gap * (size - 1)) / size;

  Rect cell(int index) => Rect.fromLTWH(
    padding + (index % size) * (tile + gap),
    padding + (index ~/ size) * (tile + gap),
    tile,
    tile,
  );
}

/// Consumed tiles sliding into their merge partner (drawn under real tiles).
class GhostPainter extends CustomPainter {
  GhostPainter(this.fx, this.geometry) : super(repaint: fx);

  final BoardFx fx;
  final BoardGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in fx._events) {
      if (e is! _Ghost) continue;
      final f = fx._f(fx._age(e), Duration.zero, FxTiming.slide);
      final from = geometry.cell(e.from);
      final to = geometry.cell(e.to);
      final rect = Rect.lerp(from, to, Curves.easeOutCubic.transform(f))!;
      if (f >= 1) continue;
      paintCreatureTile(canvas, rect, e.power);
    }
  }

  @override
  bool shouldRepaint(GhostPainter old) =>
      old.fx != fx || old.geometry.boardSize != geometry.boardSize;
}

/// Particles, score popups, celebrations and the danger rim (over tiles).
class FxOverlayPainter extends CustomPainter {
  FxOverlayPainter(this.fx, this.geometry, {required this.dangerColor})
    : super(repaint: fx);

  final BoardFx fx;
  final BoardGeometry geometry;
  final Color dangerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (fx.danger) _danger(canvas, size);
    for (final e in fx._events) {
      final t = fx._age(e);
      if (e is _Burst) {
        _burst(canvas, e, fx._f(t, FxTiming.slide, FxTiming.burst));
      } else if (e is _Popup) {
        _popup(canvas, e, fx._f(t, FxTiming.slide, FxTiming.popup));
      } else if (e is _Celebrate) {
        _celebrate(
          canvas,
          size,
          e,
          fx._f(t, FxTiming.slide, FxTiming.celebrate),
        );
      }
    }
  }

  void _danger(Canvas canvas, Size size) {
    final pulse = fx.dangerPulse;
    final rect = Offset.zero & size;
    final alpha = 0.35 + 0.45 * pulse;
    final r = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.05));
    canvas.drawRRect(
      r.deflate(size.width * 0.008),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (0.014 + 0.01 * pulse)
        ..color = dangerColor.withValues(alpha: alpha),
    );
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.75,
          colors: [
            dangerColor.withValues(alpha: 0),
            dangerColor.withValues(alpha: 0.16 + 0.2 * pulse),
          ],
          stops: const [0.72, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  void _bubble(Canvas canvas, Offset c, double r, Color color, double alpha) {
    if (alpha <= 0 || r <= 0) return;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = color.withValues(alpha: 0.35 * alpha),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.18)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * alpha),
    );
    canvas.drawCircle(
      c + Offset(-r * 0.35, -r * 0.35),
      r * 0.25,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
  }

  void _burst(Canvas canvas, _Burst e, double f) {
    if (f <= 0 || f >= 1) return;
    final rect = geometry.cell(e.index);
    final rng = math.Random(e.seed);
    final eased = Curves.easeOutCubic.transform(f);
    // Expanding ring.
    canvas.drawCircle(
      rect.center,
      rect.width * (0.4 + 0.5 * eased),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.05 * (1 - f)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.8 * (1 - f)),
    );
    for (var i = 0; i < e.count; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final speed = rect.width * (0.45 + rng.nextDouble() * 0.5);
      final r = rect.width * (0.035 + rng.nextDouble() * 0.05);
      final c =
          rect.center +
          Offset(math.cos(a), math.sin(a)) * speed * eased +
          Offset(0, -rect.width * 0.25 * f);
      _bubble(canvas, c, r * (1 - 0.3 * f), e.color, 1 - f);
    }
  }

  void _popup(Canvas canvas, _Popup e, double f) {
    if (f <= 0 || f >= 1) return;
    final rect = geometry.cell(e.index);
    final size = rect.width * 0.26;
    final tp = TextPainter(
      text: TextSpan(
        text: e.text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFFFFF).withValues(alpha: 1 - f * f),
          shadows: [
            Shadow(
              color: const Color(0xFF0B3954).withValues(alpha: 0.6 * (1 - f)),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rise = rect.width * 0.55 * Curves.easeOutCubic.transform(f);
    tp.paint(
      canvas,
      Offset(
        rect.center.dx - tp.width / 2,
        rect.top + rect.height * 0.1 - rise,
      ),
    );
  }

  void _celebrate(Canvas canvas, Size size, _Celebrate e, double f) {
    if (f <= 0 || f >= 1) return;
    final rect = geometry.cell(e.index);
    final rng = math.Random(e.seed);
    // Flash and shock ring.
    final flash = (1 - f) * (1 - f);
    canvas.drawCircle(
      rect.center,
      size.width * (e.big ? 0.75 : 0.35) * Curves.easeOutCubic.transform(f),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02 * flash
        ..color = const Color(0xFFFFF4C2).withValues(alpha: flash),
    );
    if (e.big) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              rect.center.dx / size.width * 2 - 1,
              rect.center.dy / size.height * 2 - 1,
            ),
            radius: 0.9,
            colors: [
              const Color(0xFFFFF4C2).withValues(alpha: 0.22 * flash),
              const Color(0x00FFF4C2),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    // Rising bubbles (from the whole floor when big, else from the tile).
    final count = e.big ? 46 : 18;
    const colors = [
      Color(0xFF7FDBFF),
      Color(0xFFFFD45E),
      Color(0xFFFF8EC2),
      Color(0xFF93E4B8),
      Color(0xFFC2A3FF),
    ];
    for (var i = 0; i < count; i++) {
      final delay = rng.nextDouble() * 0.35;
      final local = ((f - delay) / (1 - delay)).clamp(0.0, 1.0);
      final startX = e.big
          ? rng.nextDouble() * size.width
          : rect.center.dx + (rng.nextDouble() - 0.5) * rect.width;
      final startY = e.big ? size.height * 1.02 : rect.center.dy;
      final travel =
          (e.big ? size.height * 1.1 : size.height * 0.45) *
          (0.6 + rng.nextDouble() * 0.4);
      final wobble = math.sin(local * math.pi * 3 + i) * size.width * 0.02;
      final r = size.width * (0.008 + rng.nextDouble() * 0.018);
      final c = Offset(
        startX + wobble,
        startY - travel * Curves.easeOut.transform(local),
      );
      if (local <= 0) continue;
      _bubble(
        canvas,
        c,
        r,
        colors[i % colors.length],
        local < 0.8 ? 1 : (1 - local) / 0.2,
      );
    }
  }

  @override
  bool shouldRepaint(FxOverlayPainter old) =>
      old.fx != fx ||
      old.geometry.boardSize != geometry.boardSize ||
      old.dangerColor != dangerColor;
}
