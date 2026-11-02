import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'best_score_store.dart';
import 'game_logic.dart';
import 'how_to_play.dart';
import 'platform/game_platform.dart';
import 'result_registration.dart';
import 'src/art/creature_art.dart';
import 'src/art/sea_palette.dart';
import 'src/art/sea_scenery.dart';
import 'src/audio/sound_fx.dart';
import 'src/meta/missions.dart';
import 'src/meta/sea_progress.dart';
import 'src/meta/sea_progress_store.dart';
import 'src/meta/sea_theme.dart';
import 'src/ui/board_fx.dart';
import 'src/ui/board_view.dart';
import 'src/ui/hud.dart';
import 'src/ui/overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portal builds (CrazyGames) report gameplay events; others get a no-op.
  final platform = createGamePlatform();
  try {
    await platform.initialize();
  } catch (_) {
    // A broken portal SDK must never keep the game from starting.
  }
  runApp(SlideMergeApp(platform: platform));
}

class SlideMergeApp extends StatelessWidget {
  const SlideMergeApp({
    super.key,
    this.platform = const NoopGamePlatform(),
    this.soundFx,
  });

  final GamePlatform platform;

  /// Injectable sound effects; tests pass a recording one.
  final SoundFx? soundFx;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slide Merge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF1677A8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8A5B),
          primary: const Color(0xFFFF8A5B),
        ),
        useMaterial3: true,
      ),
      home: SlideMergeScreen(platform: platform, soundFx: soundFx),
    );
  }
}

final List<TutorialStep> _tutorialSteps = [
  const TutorialStep(
    Icons.grid_4x4,
    'Slide the sea creatures and merge twins to evolve them, from Plankton all the way to the Whale. Do not fill the tank.',
    art: _EvolveArt(),
  ),
  const TutorialStep(
    Icons.swipe,
    'Swipe, or use arrow keys / WASD, to slide every tile. Pick Classic 4x4 or Relaxed 5x5.',
  ),
  TutorialStep(
    Icons.undo,
    'Undo (button, Z or U) reverts a move. Earn a charge every ${SlideMergeGame.mergesPerCharge} merges. Missions give XP that unlocks new themes.',
  ),
];

/// Tutorial picture: two plankton make a shrimp.
class _EvolveArt extends StatelessWidget {
  const _EvolveArt();

  @override
  Widget build(BuildContext context) {
    const tile = 52.0;
    const style = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      color: Color(0xFF4F7A8F),
    );
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(dimension: tile, child: CreatureTile(power: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('+', style: style),
        ),
        SizedBox.square(dimension: tile, child: CreatureTile(power: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF4F7A8F)),
        ),
        SizedBox.square(dimension: tile + 10, child: CreatureTile(power: 2)),
      ],
    );
  }
}

class SlideMergeScreen extends StatefulWidget {
  const SlideMergeScreen({
    super.key,
    this.gameFactory,
    this.tutorialStore = const TutorialStore(),
    this.progressStore = const SeaProgressStore(),
    this.platform = const NoopGamePlatform(),
    this.soundFx,
    this.missionRandom,
  });

  /// Sound effects, music and mute switch; defaults to the real player.
  final SoundFx? soundFx;

  /// Portal hooks (gameplay events, leaderboard policy); no-op by default.
  final GamePlatform platform;

  /// First-run tutorial flag storage; tests can substitute a fake.
  final TutorialStore tutorialStore;

  /// Player level, album and theme storage.
  final SeaProgressStore progressStore;

  /// Test seam: builds the game for a mode (e.g. with a seeded Random).
  final SlideMergeGame Function(GameMode mode)? gameFactory;

  /// Test seam: random source for the run missions.
  final math.Random? missionRandom;

  @override
  State<SlideMergeScreen> createState() => _SlideMergeScreenState();
}

class _SlideMergeScreenState extends State<SlideMergeScreen> {
  static const double _swipeThreshold = 24;

  /// Empty cells at or below which the board shows the danger rim.
  static const int _dangerEmptyCells = 2;

  late SlideMergeGame _game;
  final Map<String, int> _best = {};
  final FocusNode _focus = FocusNode();
  final BoardFx _fx = BoardFx();
  bool _resultOffered = false;
  Offset _dragDelta = Offset.zero;
  bool _dragHandled = false;
  bool _tutorialOpen = false;
  int _tutorialSession = 0;
  // Gameplay events wait until the first-run tutorial check has answered.
  bool _tutorialChecked = false;
  bool _gameplayActive = false;
  bool _albumOpen = false;
  late final SoundFx _sound =
      widget.soundFx ?? SoundFx(platform: widget.platform);
  late final AppLifecycleListener _lifecycle;

  // Meta progress. Changes made before the stored value has loaded are kept
  // in _pendingProgress and replayed onto it, so nothing is overwritten.
  SeaProgress _progress = const SeaProgress.initial();
  bool _progressLoaded = false;
  final List<SeaProgress Function(SeaProgress)> _pendingProgress = [];

  // Current run.
  int _generation = 0;
  late MissionSet _missions;
  int _runHighest = 0;
  int _runMerges = 0;
  int _runBestCombo = 0;
  int _bestAtRunStart = 0;
  bool _runRecorded = false;
  RunSummaryData? _summary;

  GameMode get _mode => _game.mode;
  int get _bestScore => _best[_mode.id] ?? 0;
  SeaPalette get _palette => SeaPalette.of(_progress.selectedTheme);

  @override
  void initState() {
    super.initState();
    _sound.addListener(_onSoundChanged);
    if (widget.soundFx == null) _sound.load();
    widget.platform.setAudioMuteListener(_sound.refreshMute);
    _sound.startMusic();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _sound.setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
    HardwareKeyboard.instance.addHandler(_onAnyKey);
    _game = _newGame(GameMode.classic);
    _startRun();
    for (final mode in GameMode.all) {
      BestScoreStore.load(mode.id).then((value) {
        if (!mounted) return;
        setState(() {
          _best[mode.id] = math.max(value, _best[mode.id] ?? 0);
          if (mode.id == _mode.id) {
            _bestAtRunStart = math.max(_bestAtRunStart, value);
          }
        });
      });
    }
    _loadProgress();
    _maybeShowTutorial();
  }

  Future<void> _loadProgress() async {
    var loaded = const SeaProgress.initial();
    try {
      loaded = await widget.progressStore.load();
    } catch (_) {}
    if (!mounted) return;
    final replay = _pendingProgress.isNotEmpty;
    for (final change in _pendingProgress) {
      loaded = change(loaded);
    }
    _pendingProgress.clear();
    setState(() {
      _progress = loaded;
      _progressLoaded = true;
    });
    if (replay) unawaited(widget.progressStore.save(_progress));
  }

  /// Applies [change] now and persists it (or queues it until loaded).
  void _changeProgress(SeaProgress Function(SeaProgress) change) {
    _progress = change(_progress);
    if (_progressLoaded) {
      unawaited(widget.progressStore.save(_progress));
    } else {
      _pendingProgress.add(change);
    }
  }

  /// Any key anywhere counts as user input (browsers unlock audio on it).
  bool _onAnyKey(KeyEvent event) {
    if (event is KeyDownEvent) _sound.onUserInput();
    return false;
  }

  Future<void> _maybeShowTutorial() async {
    final session = _tutorialSession;
    var seen = false;
    try {
      seen = await widget.tutorialStore.hasSeen();
    } catch (_) {}
    if (!mounted) return;
    // Rebuild so the pointer gate in build() lifts even if nothing else does.
    setState(() => _tutorialChecked = true);
    // Ignore a stale answer if the player already opened it via "?".
    if (seen || session != _tutorialSession) {
      _syncGameplay();
      // Autofocus could not land while focus was excluded during loading.
      _refocusLater();
      return;
    }
    _openTutorial();
  }

  void _refocusLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tutorialOpen && !_albumOpen) _focus.requestFocus();
    });
  }

  /// Reports gameplay start/stop to the platform exactly on transitions:
  /// running only after the tutorial check, while no tutorial or album is
  /// open and the board still has a move.
  void _syncGameplay() {
    final wantActive =
        _tutorialChecked && !_tutorialOpen && !_albumOpen && !_game.isGameOver;
    if (wantActive == _gameplayActive) return;
    _gameplayActive = wantActive;
    try {
      if (wantActive) {
        widget.platform.gameplayStart();
      } else {
        widget.platform.gameplayStop();
      }
    } catch (_) {}
  }

  void _openTutorial() {
    _tutorialSession++;
    _dragHandled = true;
    setState(() => _tutorialOpen = true);
    _syncGameplay();
  }

  void _closeTutorial() {
    if (!_tutorialOpen) return;
    setState(() => _tutorialOpen = false);
    _syncGameplay();
    // canRequestFocus is only restored by the rebuild, so ask after the frame.
    _refocusLater();
    widget.tutorialStore.markSeen();
  }

  void _openAlbum() {
    _dragHandled = true;
    setState(() => _albumOpen = true);
    _syncGameplay();
  }

  void _closeAlbum() {
    if (!_albumOpen) return;
    setState(() => _albumOpen = false);
    _syncGameplay();
    _refocusLater();
  }

  void _selectTheme(SeaTheme theme) {
    setState(() => _changeProgress((p) => p.withTheme(theme)));
  }

  void _onSoundChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSound() {
    _sound.toggle();
    // Keep arrow keys working on the board after clicking the button.
    _focus.requestFocus();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onAnyKey);
    widget.platform.setAudioMuteListener(null);
    _lifecycle.dispose();
    _sound.removeListener(_onSoundChanged);
    if (widget.soundFx == null) {
      _sound.dispose();
    } else {
      _sound.stopMusic();
    }
    _fx.dispose();
    _focus.dispose();
    super.dispose();
  }

  SlideMergeGame _newGame(GameMode mode) =>
      widget.gameFactory?.call(mode) ?? SlideMergeGame(mode: mode);

  /// Resets the per-run state for the board currently in [_game].
  void _startRun() {
    _generation++;
    _missions = MissionSet.forRun(
      boardSize: _game.size,
      random: widget.missionRandom,
    );
    _runHighest = _game.highestPower;
    _runMerges = 0;
    _runBestCombo = 0;
    _runRecorded = false;
    _bestAtRunStart = _bestScore;
    _summary = null;
    _fx.clear();
    _fx.danger = false;
  }

  /// Turns the run into XP once. Returns the outcome, or null when the run
  /// had no move or was already recorded.
  RunOutcome? _finishRun({required bool showSummary}) {
    if (_runRecorded || _game.moves <= 0) return null;
    _runRecorded = true;
    final summary = RunSummary(
      score: _game.score,
      highestPower: _runHighest,
      moves: _game.moves,
      merges: _runMerges,
      bestCombo: _runBestCombo,
      missionXp: _missions.earnedXp,
    );
    final outcome = _progress.applyRun(summary);
    _changeProgress((p) => p.applyRun(summary).progress);
    if (showSummary) {
      _summary = RunSummaryData(
        modeLabel: _mode.label,
        score: _game.score,
        best: math.max(_bestScore, _game.score),
        isNewBest: _game.score > _bestAtRunStart && _game.score > 0,
        highestPower: math.max(1, _runHighest),
        merges: _runMerges,
        bestCombo: _runBestCombo,
        missionsDone: _missions.completedCount,
        outcome: outcome,
      );
    }
    return outcome;
  }

  void _xpBanner(RunOutcome? outcome) {
    if (outcome == null || outcome.xpGained <= 0) return;
    _fx.banner(
      '+${outcome.xpGained} XP',
      subtitle: outcome.leveledUp
          ? 'Level up! Lv ${outcome.levelAfter}'
          : 'Run saved',
      style: BannerStyle.info,
    );
    if (outcome.leveledUp) _sound.play(Sfx.levelUp);
  }

  /// Offers leaderboard registration once per finished Classic run.
  /// With [force] (restart / mode switch) a game-over run is offered even
  /// while an undo charge is still unspent.
  void _offerResultIfNeeded({bool force = false}) {
    if (!widget.platform.allowsResultRegistration) return;
    if (_mode.id != GameMode.classic.id || _resultOffered) return;
    if (!_game.isGameOver || (!force && _game.undoCharges > 0)) return;
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

  void _restart() {
    _offerResultIfNeeded(force: true);
    RunOutcome? outcome;
    setState(() {
      outcome = _finishRun(showSummary: false);
      _game.reset();
      _resultOffered = false;
      _startRun();
      _xpBanner(outcome);
    });
    _syncGameplay();
    _refocusLater();
  }

  void _setMode(GameMode mode) {
    if (mode.id == _mode.id) return;
    _offerResultIfNeeded(force: true);
    setState(() {
      final outcome = _finishRun(showSummary: false);
      _game = _newGame(mode);
      _resultOffered = false;
      _startRun();
      _xpBanner(outcome);
    });
    _syncGameplay();
    _refocusLater();
  }

  void _closeSummary() {
    if (_summary == null) return;
    setState(() => _summary = null);
    _refocusLater();
  }

  bool get _boardBlocked =>
      _tutorialOpen || !_tutorialChecked || _albumOpen || _summary != null;

  void _undo() {
    if (_boardBlocked) return;
    var undone = false;
    setState(() {
      undone = _game.undo();
      if (undone) {
        _resultOffered = false;
        _fx.clear();
        _fx.danger = _inDanger;
      }
    });
    if (undone) _sound.play(Sfx.undo);
    _syncGameplay();
  }

  bool get _inDanger =>
      !_game.isGameOver && _game.emptyCells <= _dangerEmptyCells;

  void _move(Direction direction) {
    if (_boardBlocked) return;
    final scoreBefore = _game.score;
    if (!_game.move(direction)) return;
    final report = _game.lastMove!;
    _fx.onMove(report, _game.cells);

    final merges = report.merges.length;
    _runMerges += merges;
    _runBestCombo = math.max(_runBestCombo, merges);
    MergeEvent? top;
    for (final m in report.merges) {
      if (top == null || m.power > top.power) top = m;
    }

    // Album / record tile.
    var discovered = false;
    var newRunBest = false;
    if (top != null) {
      final power = top.power;
      discovered = !_progress.isDiscovered(power);
      if (discovered || power > _progress.bestPower) {
        _changeProgress((p) => p.withTile(power));
      }
      if (power > _runHighest) {
        newRunBest = true;
        _runHighest = power;
      }
      final creature = Creature.forPower(power);
      if (discovered) {
        _fx.celebrate(top.target, big: true);
        _fx.banner(
          'New creature!',
          subtitle: '${creature.name} discovered',
          style: BannerStyle.discover,
          power: power,
        );
      } else if (newRunBest && power >= 6) {
        _fx.celebrate(top.target);
        _fx.banner(
          '${creature.name}!',
          subtitle: 'New top tile: ${1 << power}',
          style: BannerStyle.record,
          power: power,
        );
      }
    }
    if (merges >= 2) {
      _fx.banner('Combo x$merges', style: BannerStyle.combo);
    }

    // Missions.
    final done = _missions.update(
      RunStats(
        highestPower: _runHighest,
        merges: _runMerges,
        bestCombo: _runBestCombo,
        score: _game.score,
        moves: _game.moves,
      ),
    );
    for (final m in done) {
      _fx.banner(
        'Mission complete',
        subtitle: '${m.label}  +${m.xp} XP',
        style: BannerStyle.mission,
      );
    }

    // One sound per move, the most important moment wins.
    final over = _game.isGameOver;
    _sound.play(
      over
          ? Sfx.gameOver
          : discovered
          ? Sfx.discover
          : done.isNotEmpty
          ? Sfx.mission
          : merges >= 3
          ? Sfx.combo
          : _game.score > scoreBefore
          ? Sfx.merge
          : Sfx.slide,
    );
    if (_game.score > _bestScore) {
      _best[_mode.id] = _game.score;
      BestScoreStore.save(_mode.id, _game.score);
    }
    _fx.danger = _inDanger;
    if (_fx.danger) _fx.pulseDanger();
    setState(() {
      if (over && !_game.canUndo) _finishRun(showSummary: true);
    });
    _syncGameplay();
    // Scores are only comparable within one mode: Classic feeds the leaderboard.
    _offerResultIfNeeded();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Auto-repeat of action keys is swallowed without acting, so a key still
    // held from the tutorial card cannot act on the game after it closes.
    // Leave browser/OS shortcuts (Ctrl+R, Cmd+D, Alt+Left) alone.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final repeat = event is KeyRepeatEvent;
    if (_summary != null) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (!repeat) _restart();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        if (!repeat) _closeSummary();
        return KeyEventResult.handled;
      }
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => Direction.left,
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => Direction.right,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => Direction.up,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => Direction.down,
      _ => null,
    };
    if (direction != null) {
      if (!repeat) _move(direction);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ || key == LogicalKeyboardKey.keyU) {
      if (!repeat) _undo();
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
    final palette = _palette;
    return Listener(
      onPointerDown: (_) => _sound.onUserInput(),
      child: Stack(
        children: [
          Positioned.fill(child: SeaScenery(theme: palette.theme)),
          // Taps are ignored until the first-run check has answered, so the
          // tutorial cannot open on top of a half-started game.
          AbsorbPointer(
            absorbing: !_tutorialChecked,
            // Keep keyboard focus (Tab, Enter) out of the game under a card.
            child: ExcludeFocus(
              excluding: _tutorialOpen || _albumOpen || !_tutorialChecked,
              child: _buildGame(context, palette),
            ),
          ),
          if (_albumOpen)
            Positioned.fill(
              child: AlbumOverlay(
                progress: _progress,
                palette: palette,
                onTheme: _selectTheme,
                onClose: _closeAlbum,
              ),
            ),
          if (_tutorialOpen)
            Positioned.fill(
              child: HowToPlayOverlay(
                steps: _tutorialSteps,
                onClose: _closeTutorial,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGame(BuildContext context, SeaPalette palette) {
    return Scaffold(
      backgroundColor: const Color(0x00000000),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          canRequestFocus: !_tutorialOpen && !_albumOpen,
          onKeyEvent: _onKey,
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 700 && c.maxWidth > c.maxHeight * 1.15;
              return wide ? _wide(c, palette) : _narrow(c, palette);
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- layout

  static const List<Shadow> _titleShadow = [
    Shadow(color: Color(0x660B3954), blurRadius: 8, offset: Offset(0, 2)),
  ];

  Widget _title(double size) => Text(
    'Slide Merge',
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: const Color(0xFFFFFFFF),
      letterSpacing: 0.5,
      shadows: _titleShadow,
    ),
  );

  List<Widget> _iconButtons(SeaPalette palette, double size) => [
    RoundIconButton(
      icon: Icons.help_outline_rounded,
      tooltip: 'How to play',
      onPressed: _openTutorial,
      palette: palette,
      size: size,
    ),
    RoundIconButton(
      icon: Icons.collections_bookmark_rounded,
      tooltip: 'Album',
      onPressed: _openAlbum,
      palette: palette,
      size: size,
    ),
    RoundIconButton(
      icon: _sound.userMuted
          ? Icons.volume_off_rounded
          : Icons.volume_up_rounded,
      tooltip: _sound.userMuted ? 'Sound off' : 'Sound on',
      onPressed: _toggleSound,
      palette: palette,
      size: size,
    ),
    RoundIconButton(
      icon: Icons.refresh_rounded,
      tooltip: 'Restart',
      onPressed: _restart,
      palette: palette,
      size: size,
    ),
  ];

  Widget _metrics(SeaPalette palette, {required bool withLevel}) => Row(
    children: [
      Expanded(
        child: MetricTile(
          label: 'Score',
          value: '${_game.score}',
          palette: palette,
          highlight: true,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: MetricTile(
          label: 'Best',
          value: '$_bestScore',
          palette: palette,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: MetricTile(
          label: 'Moves',
          value: '${_game.moves}',
          palette: palette,
        ),
      ),
      if (withLevel) ...[
        const SizedBox(width: 6),
        Expanded(
          child: LevelCard(
            progress: _progress,
            palette: palette,
            compact: true,
          ),
        ),
      ],
    ],
  );

  Widget _controls(SeaPalette palette) => Row(
    children: [
      Expanded(
        child: ModeToggle(mode: _mode, onMode: _setMode, palette: palette),
      ),
      const SizedBox(width: 8),
      UndoButton(
        charges: _game.undoCharges,
        progress: _game.mergeProgress,
        canUndo: _game.canUndo && _summary == null,
        onUndo: _undo,
        palette: palette,
      ),
    ],
  );

  Widget _status(SeaPalette palette) {
    final over = _game.isGameOver;
    if (_summary != null) return const SizedBox(height: 20);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          over
              ? (_game.canUndo
                    ? 'No moves left. Use your undo charge or restart.'
                    : 'No moves left. Start a fresh board.')
              : 'Swipe, arrow keys or WASD to merge. Undo (Z) recharges every ${SlideMergeGame.mergesPerCharge} merges.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontWeight: FontWeight.w700,
            shadows: _titleShadow,
          ),
        ),
        if (over && !_game.canUndo) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.accentInk,
            ),
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            label: const Text('Restart'),
          ),
        ],
      ],
    );
  }

  Widget _boardArea(SeaPalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = math.max(
          0.0,
          math.min(constraints.maxWidth, constraints.maxHeight),
        );
        return Center(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            child: SizedBox.square(
              dimension: boardSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  BoardView(
                    cells: _game.cells,
                    size: _game.size,
                    boardSize: boardSize,
                    generation: _generation,
                    fx: _fx,
                    palette: palette,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: boardSize * 0.04,
                    child: Center(
                      child: FxBanners(fx: _fx, palette: palette),
                    ),
                  ),
                  if (_summary case final summary?)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(boardSize * 0.05),
                        child: RunSummaryCard(
                          key: ValueKey('summary-$_generation'),
                          data: summary,
                          palette: palette,
                          onPlayAgain: _restart,
                          onClose: _closeSummary,
                          onLevelUp: () => _sound.play(Sfx.levelUp),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _narrow(BoxConstraints c, SeaPalette palette) {
    final tight = c.maxWidth < 340;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _title(28),
                    ),
                  ),
                  for (final b in _iconButtons(palette, tight ? 36 : 40)) ...[
                    const SizedBox(width: 6),
                    b,
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _metrics(palette, withLevel: true),
              const SizedBox(height: 8),
              _controls(palette),
              const SizedBox(height: 8),
              MissionList(
                missions: _missions.missions,
                palette: palette,
                compact: true,
              ),
              const SizedBox(height: 10),
              Expanded(child: _boardArea(palette)),
              const SizedBox(height: 8),
              _status(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(double width, Widget child) => SizedBox(
    width: width,
    child: Align(
      alignment: Alignment.topCenter,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: 270, child: child),
      ),
    ),
  );

  Widget _sectionTitle(String text, SeaPalette palette) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: palette.textPrimary,
      ),
    ),
  );

  Widget _wide(BoxConstraints c, SeaPalette palette) {
    final panelWidth = (c.maxWidth * 0.24).clamp(170.0, 300.0);
    final top = Creature.forPower(math.max(1, _runHighest));
    final found = Creature.all
        .where((e) => _progress.isDiscovered(e.power))
        .length;
    final left = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(36),
        const Text(
          'Merge twins, evolve the sea!',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xEEFFFFFF),
            shadows: _titleShadow,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _iconButtons(palette, 44),
        ),
        const SizedBox(height: 14),
        _metrics(palette, withLevel: false),
        const SizedBox(height: 12),
        SeaCard(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LevelCard(progress: _progress, palette: palette),
              const SizedBox(height: 8),
              Text(
                'Theme: ${palette.theme.label}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _controls(palette),
      ],
    );
    final right = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeaCard(
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Missions', palette),
              MissionList(missions: _missions.missions, palette: palette),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SeaCard(
          palette: palette,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 72,
                child: CreatureTile(power: top.power),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top tile this run',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      top.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _openAlbum,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Album $found/${Creature.all.length}  >',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: palette.accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panel(panelWidth, left),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _boardArea(palette)),
                const SizedBox(height: 8),
                _status(palette),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _panel(panelWidth, right),
        ],
      ),
    );
  }
}
