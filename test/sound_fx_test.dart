import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:slide_merge/game_logic.dart';
import 'package:slide_merge/how_to_play.dart';
import 'package:slide_merge/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slide_merge/platform/game_platform.dart';
import 'package:slide_merge/src/audio/sound_fx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingPlayer implements SoundPlayer {
  final List<String> played = <String>[];
  bool disposed = false;

  @override
  void play(String asset, double volume) => played.add(asset);

  @override
  void dispose() => disposed = true;
}

class _RecordingMusic implements MusicPlayer {
  final List<String> calls = <String>[];
  bool result = true;

  @override
  Future<bool> play(String asset, double volume) async {
    calls.add('play');
    return result;
  }

  @override
  void pause() => calls.add('pause');

  @override
  void dispose() => calls.add('dispose');
}

class _MutedPlatform extends NoopGamePlatform {
  _MutedPlatform();

  bool muted = true;

  @override
  bool get isAudioMuted => muted;
}

class _ThrowingPlatform extends NoopGamePlatform {
  @override
  bool get isAudioMuted => throw StateError('sdk gone');
}

class _FixedRandom implements math.Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

/// Classic game with the given powers (0 = empty), spawns always power 1.
SlideMergeGame Function(GameMode) _board(List<int> powers) => (mode) {
  final g = SlideMergeGame(mode: mode, random: _FixedRandom());
  if (mode.id == GameMode.classic.id) {
    for (var i = 0; i < 16; i++) {
      g.cells[i] = powers[i] == 0 ? null : Tile(id: 100 + i, power: powers[i]);
    }
  }
  return g;
};

// One tile: moving left slides it without merging.
final _slideBoard = _board([0, 1, 0, 0, ...List.filled(12, 0)]);
// Two equal tiles in a row: moving left merges them.
final _mergeBoard = _board([1, 1, 0, 0, ...List.filled(12, 0)]);
// Full board whose only left move merges and leaves no move afterwards.
final _lastMoveBoard = _board([1, 2, 4, 3, 3, 1, 2, 4, 2, 4, 1, 2, 3, 1, 1, 4]);

Future<void> _pump(
  WidgetTester tester,
  SoundFx fx,
  SlideMergeGame Function(GameMode) factory,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SlideMergeScreen(
        gameFactory: factory,
        tutorialStore: _SeenStore(),
        soundFx: fx,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SeenStore extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SoundFx', () {
    test('plays the asset of each effect at a volume', () {
      final player = _RecordingPlayer();
      SoundFx(player: player).play(Sfx.slide);
      expect(player.played, ['assets/audio/slide.wav']);
    });

    test('user mute silences effects and platform mute does too', () async {
      final player = _RecordingPlayer();
      final platform = _MutedPlatform()..muted = false;
      final fx = SoundFx(platform: platform, player: player);

      await fx.setUserMuted(true);
      fx.play(Sfx.slide);
      expect(player.played, isEmpty);

      await fx.setUserMuted(false);
      fx.play(Sfx.slide);
      expect(player.played, hasLength(1));

      platform.muted = true;
      expect(fx.muted, isTrue);
      expect(fx.userMuted, isFalse);
      fx.play(Sfx.gameOver);
      expect(player.played, hasLength(1));
    });

    test('a failing platform getter counts as not muted', () {
      final player = _RecordingPlayer();
      SoundFx(platform: _ThrowingPlatform(), player: player).play(Sfx.undo);
      expect(player.played, hasLength(1));
    });

    test('mute choice persists under sound_muted_v1', () async {
      final fx = SoundFx(player: _RecordingPlayer());
      await fx.setUserMuted(true);
      expect(
        (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
        isTrue,
      );

      final reloaded = SoundFx(player: _RecordingPlayer());
      expect(reloaded.userMuted, isFalse);
      await reloaded.load();
      expect(reloaded.userMuted, isTrue);
    });

    test('defaults to sound on when nothing is stored', () async {
      final fx = SoundFx(player: _RecordingPlayer());
      await fx.load();
      expect(fx.userMuted, isFalse);
    });

    test('a toggle made before load finishes is not overwritten', () async {
      SharedPreferences.setMockInitialValues({'sound_muted_v1': true});
      final fx = SoundFx(player: _RecordingPlayer());
      final loading = fx.load();
      await fx.setUserMuted(false);
      await loading;
      expect(fx.userMuted, isFalse);
    });

    test('player and storage failures never throw', () async {
      final fx = SoundFx(
        player: _ThrowingPlayer(),
        preferences: () async => throw StateError('no storage'),
      );
      await fx.load();
      await fx.setUserMuted(true);
      await fx.setUserMuted(false);
      fx.play(Sfx.slide);
    });

    test('the platform player tolerates a missing native channel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final player = PlatformSoundPlayer();
      player.play(Sfx.slide.asset, 0.5);
      player.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    test('dispose releases the player and later calls are harmless', () async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player)..dispose();
      expect(player.disposed, isTrue);
      fx.play(Sfx.slide);
      await fx.setUserMuted(true);
      expect(player.played, isEmpty);
    });
  });

  group('assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('pubspec bundles the audio directory', () {
      expect(pubspec, contains('- assets/audio/'));
    });

    for (final sfx in Sfx.values) {
      test('${sfx.name} exists on disk and is small', () {
        final file = File(sfx.asset);
        expect(file.existsSync(), isTrue, reason: sfx.asset);
        expect(file.lengthSync(), lessThan(40 * 1024));
      });
    }

    test('every asset used in lib/ is covered by Sfx', () {
      final used = <String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        used.addAll(
          RegExp(
            r'assets/audio/[a-z_]+\.wav',
          ).allMatches(entity.readAsStringSync()).map((m) => m.group(0)!),
        );
      }
      // Only the Sfx.asset template and the music loop are spelled out in
      // code; the effect list comes from the enum.
      expect(used, {SoundFx.musicAsset});
      final onDisk = Directory(
        'assets/audio',
      ).listSync().map((e) => e.path).where((p) => p.endsWith('.wav')).toSet();
      expect(onDisk, {...Sfx.values.map((s) => s.asset), SoundFx.musicAsset});
    });

    test('music loop: 16 kHz mono 16-bit, under 1 MB', () {
      final bytes = File(SoundFx.musicAsset).readAsBytesSync();
      expect(bytes.length, lessThan(1024 * 1024));
      final header = bytes.buffer.asByteData();
      expect(header.getUint16(22, Endian.little), 1); // channels
      expect(header.getUint32(24, Endian.little), 16000); // sample rate
      expect(header.getUint16(34, Endian.little), 16); // bits per sample
    });
  });

  group('music', () {
    SoundFx music(_RecordingMusic m, {bool web = false, GamePlatform? p}) =>
        SoundFx(
          player: _RecordingPlayer(),
          music: m,
          musicNeedsGesture: web,
          platform: p ?? const NoopGamePlatform(),
        );

    test('starts when wanted and stops for the user toggle', () async {
      final m = _RecordingMusic();
      final fx = music(m)..startMusic();
      expect(m.calls, ['play']);
      expect(fx.isMusicPlaying, isTrue);
      await fx.setUserMuted(true);
      expect(m.calls, ['play', 'pause']);
      await fx.setUserMuted(false);
      expect(m.calls, ['play', 'pause', 'play']);
    });

    test('web waits for the first user input', () {
      final m = _RecordingMusic();
      final fx = music(m, web: true)..startMusic();
      expect(m.calls, isEmpty);
      fx.onUserInput();
      expect(m.calls, ['play']);
      fx.onUserInput();
      expect(m.calls, ['play']);
    });

    test('a refused start is retried on the next input', () async {
      final m = _RecordingMusic()..result = false;
      final fx = music(m, web: true)..startMusic();
      fx.onUserInput();
      await Future<void>.delayed(Duration.zero);
      expect(fx.isMusicPlaying, isFalse);
      m.result = true;
      fx.onUserInput();
      expect(m.calls, ['play', 'play']);
      expect(fx.isMusicPlaying, isTrue);
    });

    test('pauses while the app is hidden', () {
      final m = _RecordingMusic();
      final fx = music(m)..startMusic();
      fx.setAppVisible(false);
      fx.setAppVisible(false);
      fx.setAppVisible(true);
      expect(m.calls, ['play', 'pause', 'play']);
    });

    test('follows the platform mute through refreshMute', () {
      final m = _RecordingMusic();
      final platform = _MutedPlatform()..muted = false;
      final fx = music(m, p: platform)..startMusic();
      platform.muted = true;
      fx.refreshMute();
      platform.muted = false;
      fx.refreshMute();
      expect(m.calls, ['play', 'pause', 'play']);
    });

    test('a muted start never plays; dispose stops it', () async {
      final m = _RecordingMusic();
      final fx = music(m);
      await fx.setUserMuted(true);
      fx.startMusic();
      expect(m.calls, isEmpty);
      await fx.setUserMuted(false);
      fx.dispose();
      expect(m.calls, ['play', 'dispose']);
      fx.startMusic();
      expect(m.calls, ['play', 'dispose']);
    });

    test('a test effects player gets no music by default', () {
      // Nothing to observe except that it does not throw.
      SoundFx(player: _RecordingPlayer())
        ..startMusic()
        ..onUserInput()
        ..dispose();
    });
  });

  group('game hooks', () {
    testWidgets('a plain slide plays slide once; a blocked move is silent', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _slideBoard);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(player.played, ['assets/audio/slide.wav']);

      // Both tiles already sit against the top wall: nothing changes.
      player.played.clear();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(player.played, isEmpty);
    });

    testWidgets('a move that merges plays merge once instead of slide', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _mergeBoard);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(player.played, ['assets/audio/merge.wav']);
    });

    testWidgets('swipes play the same sounds as keys', (tester) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _slideBoard);

      await tester.drag(
        find.byType(AnimatedPositioned).first,
        const Offset(-120, 0),
      );
      await tester.pump();
      expect(player.played, ['assets/audio/slide.wav']);
    });

    testWidgets('undo plays only when it reverts a move', (tester) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _slideBoard);

      await _key(tester, LogicalKeyboardKey.keyZ);
      expect(player.played, isEmpty);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      player.played.clear();
      await _key(tester, LogicalKeyboardKey.keyZ);
      expect(player.played, ['assets/audio/undo.wav']);

      // The only charge is spent.
      player.played.clear();
      await _key(tester, LogicalKeyboardKey.keyZ);
      expect(player.played, isEmpty);
    });

    testWidgets('the undo button plays undo', (tester) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _slideBoard);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      player.played.clear();
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(player.played, ['assets/audio/undo.wav']);
    });

    testWidgets('the move that ends the run plays game_over only', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _lastMoveBoard);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.textContaining('No moves left'), findsOneWidget);
      expect(player.played, ['assets/audio/game_over.wav']);
    });

    testWidgets('restart and mode switch are silent', (tester) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _slideBoard);

      await tester.tap(find.byTooltip('Restart'));
      await tester.pump();
      await tester.tap(find.text('Relaxed 5x5'));
      await tester.pump();
      expect(player.played, isEmpty);
    });

    testWidgets('muted game stays silent', (tester) async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player);
      await fx.setUserMuted(true);
      await _pump(tester, fx, _mergeBoard);

      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(player.played, isEmpty);
    });

    testWidgets('the toggle flips icon, tooltip and stored state', (
      tester,
    ) async {
      final fx = SoundFx(player: _RecordingPlayer());
      await _pump(tester, fx, _slideBoard);

      expect(find.byTooltip('Sound on'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Sound on'));
      await tester.pump();
      expect(fx.userMuted, isTrue);
      expect(find.byTooltip('Sound off'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
        isTrue,
      );

      await tester.tap(find.byTooltip('Sound off'));
      await tester.pump();
      expect(fx.userMuted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('the board keeps keyboard focus after using the toggle', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player), _slideBoard);

      await tester.tap(find.byTooltip('Sound on'));
      await tester.pump();
      await tester.tap(find.byTooltip('Sound off'));
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(player.played, ['assets/audio/slide.wav']);
    });

    testWidgets('Space after using the toggle does not press it again', (
      tester,
    ) async {
      final fx = SoundFx(player: _RecordingPlayer());
      await _pump(tester, fx, _slideBoard);

      await tester.tap(find.byTooltip('Sound on'));
      await tester.pump();
      expect(fx.userMuted, isTrue);
      await _key(tester, LogicalKeyboardKey.space);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(fx.userMuted, isTrue);
    });

    for (final width in const [320.0, 360.0]) {
      testWidgets('header with the sound button fits at $width px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const SlideMergeApp());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Sound on'), findsOneWidget);
      });
    }

    testWidgets('a stored mute choice is applied on launch', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_muted_v1': true,
        'tutorial_seen_v1': true,
      });
      await tester.pumpWidget(const SlideMergeApp());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sound off'), findsOneWidget);
    });

    testWidgets('the toggle is blocked while the tutorial card is open', (
      tester,
    ) async {
      final fx = SoundFx(player: _RecordingPlayer());
      await _pump(tester, fx, _slideBoard);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      await tester.tap(find.byTooltip('Sound on'), warnIfMissed: false);
      await tester.pump();
      expect(fx.userMuted, isFalse);
    });
  });
}

class _ThrowingPlayer implements SoundPlayer {
  @override
  void play(String asset, double volume) => throw StateError('boom');

  @override
  void dispose() => throw StateError('boom');
}
