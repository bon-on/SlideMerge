import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'best_score_store.dart';
import 'game_logic.dart';
import 'result_registration.dart';

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
  static const double _swipeThreshold = 24;
  static const double _maxContentWidth = 520;

  late SlideMergeGame _game;
  final Map<String, int> _best = {};
  final FocusNode _focus = FocusNode();
  bool _resultOffered = false;
  Offset _dragDelta = Offset.zero;
  bool _dragHandled = false;

  GameMode get _mode => _game.mode;
  int get _bestScore => _best[_mode.id] ?? 0;

  @override
  void initState() {
    super.initState();
    _game = SlideMergeGame(mode: GameMode.classic);
    for (final mode in GameMode.all) {
      BestScoreStore.load(mode.id).then((value) {
        if (!mounted) return;
        setState(() => _best[mode.id] = math.max(value, _best[mode.id] ?? 0));
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      _game.reset();
      _resultOffered = false;
    });
  }

  void _setMode(GameMode mode) {
    if (mode.id == _mode.id) return;
    setState(() {
      _game = SlideMergeGame(mode: mode);
      _resultOffered = false;
    });
  }

  void _undo() {
    setState(() {
      if (_game.undo()) _resultOffered = false;
    });
  }

  void _move(Direction direction) {
    if (!_game.move(direction)) return;
    if (_game.score > _bestScore) {
      _best[_mode.id] = _game.score;
      BestScoreStore.save(_mode.id, _game.score);
    }
    setState(() {});
    // Scores are only comparable within one mode: Classic feeds the leaderboard.
    final finished = _game.isGameOver && _game.undoCharges == 0;
    if (finished && !_resultOffered && _mode.id == GameMode.classic.id) {
      _resultOffered = true;
      final score = _game.score;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          offerResultRegistration(
            context,
            gameId: 'slide-merge',
            metric: 'score',
            value: score,
            displayValue: '$score점',
          );
        }
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => Direction.left,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => Direction.right,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => Direction.up,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => Direction.down,
      _ => null,
    };
    if (direction != null) {
      _move(direction);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.keyU) {
      _undo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onPanStart(DragStartDetails d) {
    _dragDelta = Offset.zero;
    _dragHandled = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragHandled) return;
    _dragDelta += d.delta;
    if (_dragDelta.distance < _swipeThreshold) return;
    _dragHandled = true;
    if (_dragDelta.dx.abs() > _dragDelta.dy.abs()) {
      _move(_dragDelta.dx > 0 ? Direction.right : Direction.left);
    } else {
      _move(_dragDelta.dy > 0 ? Direction.down : Direction.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    final over = _game.isGameOver;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  children: [
                    _Header(
                      score: _game.score,
                      best: _bestScore,
                      moves: _game.moves,
                      onRestart: _restart,
                    ),
                    const SizedBox(height: 8),
                    _Controls(
                      mode: _mode,
                      onMode: _setMode,
                      charges: _game.undoCharges,
                      progress: _game.mergeProgress,
                      canUndo: _game.canUndo,
                      onUndo: _undo,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boardSize = math.max(
                            0.0,
                            math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                          );
                          return Center(
                            child: GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              child: _MergeBoard(
                                cells: _game.cells,
                                size: _game.size,
                                lastSpawnedId: _game.lastSpawnedId,
                                boardSize: boardSize,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      over
                          ? (_game.canUndo
                                ? 'No moves left. Use your undo charge or restart.'
                                : 'No moves left. Start a fresh board.')
                          : 'Swipe, arrow keys or WASD to merge. Undo (Z) recharges every ${SlideMergeGame.mergesPerCharge} merges.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCFE2DE),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (over && !_game.canUndo) ...[
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
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.mode,
    required this.onMode,
    required this.charges,
    required this.progress,
    required this.canUndo,
    required this.onUndo,
  });

  final GameMode mode;
  final ValueChanged<GameMode> onMode;
  final int charges;
  final int progress;
  final bool canUndo;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<GameMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
            ),
            segments: [
              for (final m in GameMode.all)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onMode(s.first),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: charges > 0
              ? 'Undo last move'
              : 'Next charge in ${SlideMergeGame.mergesPerCharge - progress} merges',
          child: FilledButton.tonalIcon(
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo, size: 18),
            label: Text(
              charges > 0
                  ? 'Undo'
                  : '$progress/${SlideMergeGame.mergesPerCharge}',
            ),
          ),
        ),
      ],
    );
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
    required this.size,
    required this.lastSpawnedId,
    required this.boardSize,
  });

  final List<Tile?> cells;
  final int size;
  final int? lastSpawnedId;
  final double boardSize;

  @override
  Widget build(BuildContext context) {
    const gap = 7.0;
    final tileSize = (boardSize - gap * (size - 1)) / size;

    return SizedBox.square(
      dimension: boardSize,
      child: Stack(
        children: [
          for (var index = 0; index < cells.length; index++)
            Positioned(
              left: (index % size) * (tileSize + gap),
              top: (index ~/ size) * (tileSize + gap),
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
                left: (index % size) * (tileSize + gap),
                top: (index ~/ size) * (tileSize + gap),
                width: tileSize,
                height: tileSize,
                child: _MergeTile(
                  power: tile.power,
                  fontScale: tileSize / 70,
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
  const _MergeTile({
    required this.power,
    required this.isNew,
    required this.fontScale,
  });

  final int power;
  final bool isNew;
  final double fontScale;

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
            fontSize: (power < 10 ? 22 : 17) * fontScale.clamp(0.6, 1.4),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
