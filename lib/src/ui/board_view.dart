import 'package:flutter/widgets.dart';

import '../../game_logic.dart';
import '../art/creature_art.dart';
import '../art/sea_palette.dart';
import 'board_fx.dart';

/// The glass tank with its cells, sliding creature tiles and effect layers.
///
/// Every tile is an `AnimatedPositioned` keyed by its id (plus a board
/// generation, so a new run never animates from the old board), which makes
/// tiles visibly travel. Pops, spawns, ghosts and particles come from [fx].
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.cells,
    required this.size,
    required this.boardSize,
    required this.generation,
    required this.fx,
    required this.palette,
  });

  final List<Tile?> cells;
  final int size;
  final double boardSize;
  final int generation;
  final BoardFx fx;
  final SeaPalette palette;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.fx.attach(this);
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fx != widget.fx) {
      oldWidget.fx.detach(this);
      widget.fx.attach(this);
    }
  }

  @override
  void dispose() {
    widget.fx.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = BoardGeometry(
      boardSize: widget.boardSize,
      size: widget.size,
    );
    final palette = widget.palette;
    return SizedBox.square(
      dimension: widget.boardSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TankPainter(geometry, palette, widget.cells.length),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: GhostPainter(widget.fx, geometry)),
              ),
            ),
          ),
          for (var index = 0; index < widget.cells.length; index++)
            if (widget.cells[index] case final tile?)
              AnimatedPositioned(
                key: ValueKey('${widget.generation}-${tile.id}'),
                duration: FxTiming.slide,
                curve: Curves.easeOutCubic,
                left: geometry.cell(index).left,
                top: geometry.cell(index).top,
                width: geometry.tile,
                height: geometry.tile,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _TilePainter(widget.fx, tile.id, tile.power),
                  ),
                ),
              ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: FxOverlayPainter(
                    widget.fx,
                    geometry,
                    dangerColor: palette.danger,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.fx, this.id, this.power) : super(repaint: fx.tiles);

  final BoardFx fx;
  final int id;
  final int power;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = fx.tileScale(id);
    if (scale <= 0) return;
    final shown = fx.shownPower(id) ?? power;
    final rect = Offset.zero & size;
    final scaled = Rect.fromCenter(
      center: rect.center,
      width: size.width * scale,
      height: size.height * scale,
    );
    paintCreatureTile(canvas, scaled, shown);
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.fx != fx || old.id != id || old.power != power;
}

class _TankPainter extends CustomPainter {
  _TankPainter(this.geometry, this.palette, this.cellCount);

  final BoardGeometry geometry;
  final SeaPalette palette;
  final int cellCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.05);
    final tank = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(
      tank.shift(Offset(0, size.width * 0.012)),
      Paint()..color = const Color(0x33021C30),
    );
    canvas.drawRRect(tank, Paint()..color = palette.board);
    // Glass sheen on the upper left.
    canvas.save();
    canvas.clipRRect(tank);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.45, 0)
        ..lineTo(0, size.height * 0.45)
        ..close(),
      Paint()..color = const Color(0x14FFFFFF),
    );
    canvas.restore();
    canvas.drawRRect(
      tank.deflate(size.width * 0.004),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.008
        ..color = palette.boardBorder,
    );
    final cellRadius = Radius.circular(geometry.tile * 0.2);
    for (var i = 0; i < cellCount; i++) {
      final cell = RRect.fromRectAndRadius(geometry.cell(i), cellRadius);
      canvas.drawRRect(cell, Paint()..color = palette.cell);
      canvas.drawRRect(
        cell.deflate(geometry.tile * 0.02),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = geometry.tile * 0.02
          ..color = palette.cellShade,
      );
    }
  }

  @override
  bool shouldRepaint(_TankPainter old) =>
      old.palette != palette ||
      old.cellCount != cellCount ||
      old.geometry.boardSize != geometry.boardSize;
}
