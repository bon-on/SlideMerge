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
  late List<int> _cells;
  int _score = 0;
  int _moves = 0;
  int _best = 0;

  bool get _isGameOver {
    if (_cells.any((cell) => cell == 0)) return false;
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        final value = _cells[_index(row, col)];
        if (row + 1 < size && _cells[_index(row + 1, col)] == value) {
          return false;
        }
        if (col + 1 < size && _cells[_index(row, col + 1)] == value) {
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
    _cells = List<int>.filled(size * size, 0);
    _score = 0;
    _moves = 0;
    _spawn();
    _spawn();
    setState(() {});
  }

  int _index(int row, int col) => row * size + col;

  void _spawn() {
    final empty = <int>[];
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] == 0) empty.add(i);
    }
    if (empty.isEmpty) return;
    _cells[empty[_random.nextInt(empty.length)]] = _random.nextDouble() < 0.82
        ? 1
        : 2;
  }

  void _slide(_Direction direction) {
    final before = List<int>.from(_cells);
    var gained = 0;

    for (var line = 0; line < size; line++) {
      final values = <int>[];
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
        final value = _cells[_index(row, col)];
        if (value != 0) values.add(value);
      }

      final merged = <int>[];
      for (var i = 0; i < values.length; i++) {
        if (i + 1 < values.length && values[i] == values[i + 1]) {
          final next = values[i] + 1;
          merged.add(next);
          gained += 1 << next;
          i++;
        } else {
          merged.add(values[i]);
        }
      }
      while (merged.length < size) {
        merged.add(0);
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
        _cells[_index(row, col)] = merged[step];
      }
    }

    if (!_sameBoard(before, _cells)) {
      _moves++;
      _score += gained;
      _best = math.max(_best, _score);
      _spawn();
      setState(() {});
    }
  }

  bool _sameBoard(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
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
                        child: SizedBox.square(
                          dimension: boardSize,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cells.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: size,
                                  crossAxisSpacing: 7,
                                  mainAxisSpacing: 7,
                                ),
                            itemBuilder: (context, index) =>
                                _MergeTile(power: _cells[index]),
                          ),
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
                    : 'Swipe to merge matching tiles. Bigger boards, slower pressure.',
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

class _MergeTile extends StatelessWidget {
  const _MergeTile({required this.power});

  final int power;

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
