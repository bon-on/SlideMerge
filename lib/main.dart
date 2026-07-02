import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() => runApp(const SlideMergeApp());

class SlideMergeApp extends StatelessWidget {
  const SlideMergeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slide Merge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111614),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SlideMergeScreen(),
    );
  }
}

class SlideMergeScreen extends StatefulWidget {
  const SlideMergeScreen({super.key});

  @override
  State<SlideMergeScreen> createState() => _SlideMergeScreenState();
}

class _SlideMergeScreenState extends State<SlideMergeScreen> {
  static const int size = 5;
  final math.Random _random = math.Random();
  late List<_GameTile?> _cells;
  int _score = 0;
  int _moves = 0;
  int _best = 0;
  int? _lastSpawnedId;
  int _nextTileId = 1;

  bool get _isGameOver {
    if (_cells.any((cell) => cell == null)) return false;
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final value = _cells[_index(row, col)]!.power;
        if (row + 1 < size && _cells[_index(row + 1, col)]?.power == value) {
          return false;
        }
        if (col + 1 < size && _cells[_index(row, col + 1)]?.power == value) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _cells = List<_GameTile?>.filled(size * size, null);
    _score = 0;
    _moves = 0;
    _nextTileId = 1;
    _spawn(mark: false);
    _spawn(mark: false);
    _lastSpawnedId = null;
    setState(() {});
  }

  int _index(int row, int col) => row * size + col;

  void _spawn({bool mark = true}) {
    final empty = <int>[];
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] == null) empty.add(i);
    }
    if (empty.isEmpty) return;
    final index = empty[_random.nextInt(empty.length)];
    final tile = _GameTile(
      id: _nextTileId++,
      power: _random.nextDouble() < 0.82 ? 1 : 2,
    );
    _cells[index] = tile;
    _lastSpawnedId = mark ? tile.id : null;
  }

  void _slide(_Direction direction) {
    final before = List<_GameTile?>.from(_cells);
    final nextCells = List<_GameTile?>.filled(size * size, null);
    var gained = 0;

    for (var line = 0; line < size; line++) {
      final tiles = <_GameTile>[];
      for (var step = 0; step < size; step++) {
        final row = switch (direction) {
          _Direction.left || _Direction.right => line,
          _Direction.up => step,
          _Direction.down => size - 1 - step,
        };
        final col = switch (direction) {
          _Direction.up || _Direction.down => line,
          _Direction.left => step,
          _Direction.right => size - 1 - step,
        };
        final tile = _cells[_index(row, col)];
        if (tile != null) tiles.add(tile);
      }

      final merged = <_GameTile>[];
      for (var i = 0; i < tiles.length; i++) {
        if (i + 1 < tiles.length && tiles[i].power == tiles[i + 1].power) {
          final next = tiles[i].power + 1;
          merged.add(tiles[i].copyWith(power: next));
          gained += 1 << next;
          i++;
        } else {
          merged.add(tiles[i]);
        }
      }

      for (var step = 0; step < size; step++) {
        final row = switch (direction) {
          _Direction.left || _Direction.right => line,
          _Direction.up => step,
          _Direction.down => size - 1 - step,
        };
        final col = switch (direction) {
          _Direction.up || _Direction.down => line,
          _Direction.left => step,
          _Direction.right => size - 1 - step,
        };
        if (step < merged.length) {
          nextCells[_index(row, col)] = merged[step];
        }
      }
    }

    if (!_sameBoard(before, nextCells)) {
      _moves++;
      _score += gained;
      _best = math.max(_best, _score);
      _cells = nextCells;
      _spawn();
      setState(() {});
    }
  }

  bool _sameBoard(List<_GameTile?> a, List<_GameTile?> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i]?.id != b[i]?.id || a[i]?.power != b[i]?.power) return false;
    }
    return true;
  }

  void _handleDrag(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 160) return;
    if (velocity.dx.abs() > velocity.dy.abs()) {
      _slide(velocity.dx > 0 ? _Direction.right : _Direction.left);
    } else {
      _slide(velocity.dy > 0 ? _Direction.down : _Direction.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              _Header(
                score: _score,
                best: _best,
                moves: _moves,
                onRestart: _restart,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Center(
                      child: GestureDetector(
                        onHorizontalDragEnd: _handleDrag,
                        onVerticalDragEnd: _handleDrag,
                        child: _MergeBoard(
                          cells: _cells,
                          lastSpawnedId: _lastSpawnedId,
                          boardSize: boardSize,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isGameOver
                    ? 'No moves left. Start a fresh board.'
                    : 'Swipe to merge. After each move, a new tile appears in a random empty cell.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCFE2DE),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isGameOver) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Direction { left, right, up, down }

class _GameTile {
  const _GameTile({required this.id, required this.power});

  final int id;
  final int power;

  _GameTile copyWith({required int power}) {
    return _GameTile(id: id, power: power);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.score,
    required this.best,
    required this.moves,
    required this.onRestart,
  });

  final int score;
  final int best;
  final int moves;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Slide Merge',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        _Metric(label: 'Score', value: '$score'),
        const SizedBox(width: 6),
        _Metric(label: 'Best', value: '$best'),
        const SizedBox(width: 6),
        _Metric(label: 'Moves', value: '$moves'),
        IconButton(
          onPressed: onRestart,
          tooltip: 'Restart',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2522),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8EA5A0)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MergeBoard extends StatelessWidget {
  const _MergeBoard({
    required this.cells,
    required this.lastSpawnedId,
    required this.boardSize,
  });

  final List<_GameTile?> cells;
  final int? lastSpawnedId;
  final double boardSize;

  @override
  Widget build(BuildContext context) {
    const gap = 7.0;
    final tileSize =
        (boardSize - gap * (_SlideMergeScreenState.size - 1)) /
        _SlideMergeScreenState.size;

    return SizedBox.square(
      dimension: boardSize,
      child: Stack(
        children: [
          for (var index = 0; index < cells.length; index++)
            Positioned(
              left: (index % _SlideMergeScreenState.size) * (tileSize + gap),
              top: (index ~/ _SlideMergeScreenState.size) * (tileSize + gap),
              width: tileSize,
              height: tileSize,
              child: const _TileBase(),
            ),
          for (var index = 0; index < cells.length; index++)
            if (cells[index] case final tile?)
              AnimatedPositioned(
                key: ValueKey(tile.id),
                duration: const Duration(milliseconds: 210),
                curve: Curves.easeOutCubic,
                left: (index % _SlideMergeScreenState.size) * (tileSize + gap),
                top: (index ~/ _SlideMergeScreenState.size) * (tileSize + gap),
                width: tileSize,
                height: tileSize,
                child: _MergeTile(
                  power: tile.power,
                  isNew: tile.id == lastSpawnedId,
                ),
              ),
        ],
      ),
    );
  }
}

class _TileBase extends StatelessWidget {
  const _TileBase();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1B2522),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _MergeTile extends StatelessWidget {
  const _MergeTile({required this.power, required this.isNew});

  final int power;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final color = power == 0
        ? const Color(0xFF1B2522)
        : Color.lerp(
            const Color(0xFF38BDF8),
            const Color(0xFFFACC15),
            (power / 12).clamp(0, 1),
          )!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: isNew
            ? Border.all(color: const Color(0xFFFFFFFF), width: 2.5)
            : null,
      ),
      child: Center(
        child: Text(
          power == 0 ? '' : '${1 << power}',
          style: TextStyle(
            color: power < 6 ? const Color(0xFF0B1110) : Colors.white,
            fontSize: power < 10 ? 22 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
