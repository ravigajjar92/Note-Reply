import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/canvas_settings_repository.dart';
import 'package:note_replay_animation/domain/models/canvas_settings.dart';
import 'package:note_replay_animation/ui/replay/view_models/note_replay_view_model.dart';

import '../../../helpers/fake_note_repository.dart';
import '../../../helpers/manual_frame_clock.dart';

void main() {
  late FakeNoteRepository repository;
  late CanvasSettingsRepository settings;
  late ManualFrameClock clock;
  late NoteReplayViewModel viewModel;

  setUp(() {
    repository = FakeNoteRepository();
    settings = CanvasSettingsRepository();
    clock = ManualFrameClock();
    viewModel = NoteReplayViewModel(
      note: testSummary,
      noteRepository: repository,
      settingsRepository: settings,
      clock: clock,
    );
  });

  tearDown(() {
    viewModel.dispose();
    settings.dispose();
  });

  Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

  group('load', () {
    test('starts loading', () {
      expect(viewModel.loadState.value, isA<NoteLoading>());
    });

    test('shows the complete note, without playing', () async {
      await viewModel.load();

      expect(viewModel.loadState.value, isA<NoteReady>());
      expect(viewModel.status.value, PlaybackStatus.ready);
      expect(viewModel.duration, closeTo(0.7, 1e-9));
      expect(viewModel.frame.time, viewModel.duration);
      expect(viewModel.committedStrokes.value, 2);
      expect(clock.isRunning, isFalse);
    });

    test('shows the error, and Retry loads the note', () async {
      repository.loadError = Exception('unreadable');

      await viewModel.load();
      expect(viewModel.loadState.value, isA<NoteLoadError>());

      repository.loadError = null;
      await viewModel.load();
      expect(viewModel.loadState.value, isA<NoteReady>());
    });

    test('with autoPlay, starts playing from the start', () async {
      await viewModel.load(autoPlay: true);

      expect(viewModel.status.value, PlaybackStatus.playing);
      expect(clock.isRunning, isTrue);
      expect(viewModel.frame.time, 0);
    });

    test('playback commands do nothing before the note loads', () {
      viewModel
        ..togglePlayback()
        ..beginSeek()
        ..seekTo(0.2)
        ..endSeek();

      expect(viewModel.status.value, PlaybackStatus.ready);
      expect(clock.isRunning, isFalse);
    });
  });

  group('togglePlayback', () {
    setUp(() => viewModel.load());

    test('from the complete note, plays from the start', () {
      viewModel.togglePlayback();

      expect(viewModel.status.value, PlaybackStatus.playing);
      expect(clock.isRunning, isTrue);
      expect(viewModel.frame.time, 0);
      expect(viewModel.committedStrokes.value, 0);
    });

    test('playback time follows the clock', () {
      viewModel.togglePlayback();

      clock.tick(ms(150));

      expect(viewModel.frame.time, closeTo(0.15, 1e-9));
      expect(viewModel.frame.activeStroke, 0);
      expect(viewModel.clockTenths.value, 1);
    });

    test('pauses and resumes where it stopped', () {
      viewModel.togglePlayback();
      clock.tick(ms(300));

      viewModel.togglePlayback();
      expect(viewModel.status.value, PlaybackStatus.paused);
      expect(clock.isRunning, isFalse);

      viewModel.togglePlayback();
      expect(viewModel.status.value, PlaybackStatus.playing);
      clock.tick(Duration.zero);
      expect(viewModel.frame.time, closeTo(0.3, 1e-9));
      clock.tick(ms(200));
      expect(viewModel.frame.time, closeTo(0.5, 1e-9));
    });

    test('completes at the end, stops the clock, then replays from 0', () {
      viewModel.togglePlayback();

      clock.tick(ms(2000));

      expect(viewModel.status.value, PlaybackStatus.completed);
      expect(clock.isRunning, isFalse);
      expect(viewModel.frame.time, viewModel.duration);
      expect(viewModel.committedStrokes.value, 2);

      viewModel.togglePlayback();
      expect(viewModel.status.value, PlaybackStatus.playing);
      expect(viewModel.frame.time, 0);
    });
  });

  group('pen intervals', () {
    setUp(() => viewModel.load());

    test('are empty on the complete note', () {
      expect(viewModel.penWritingMicros.value, isNull);
      expect(viewModel.penLiftMicros.value, isNull);
    });

    test('pen down shows the microseconds to the next sample', () {
      viewModel.togglePlayback();
      clock.tick(ms(150));

      expect(viewModel.penWritingMicros.value, 100000);
      expect(viewModel.penLiftMicros.value, isNull);
    });

    test('pen up shows the microseconds between the strokes', () {
      viewModel.togglePlayback();
      clock.tick(ms(400));

      expect(viewModel.penWritingMicros.value, isNull);
      expect(viewModel.penLiftMicros.value, 200000);
    });

    test('notify only when the value changes', () {
      viewModel.togglePlayback();
      clock.tick(ms(110));
      var notifications = 0;
      viewModel.penWritingMicros.addListener(() => notifications++);

      // Same 100 ms sample gap for every frame in the first stroke.
      clock
        ..tick(ms(150))
        ..tick(ms(190))
        ..tick(ms(250));

      expect(notifications, 0);
    });
  });

  group('seek', () {
    setUp(() => viewModel.load());

    test('from the complete note, stays paused where it was dragged', () {
      viewModel
        ..beginSeek()
        ..seekTo(0.4)
        ..endSeek();

      expect(viewModel.status.value, PlaybackStatus.paused);
      expect(clock.isRunning, isFalse);
      expect(viewModel.frame.time, 0.4);
      expect(viewModel.committedStrokes.value, 1);
      expect(viewModel.frame.activeStroke, -1);
    });

    test('while playing, pauses during the drag and resumes from the new '
        'time', () {
      viewModel.togglePlayback();
      clock.tick(ms(100));

      viewModel
        ..beginSeek()
        ..seekTo(0.55);
      expect(clock.isRunning, isFalse);

      viewModel.endSeek();
      expect(viewModel.status.value, PlaybackStatus.playing);
      clock.tick(ms(100));
      expect(viewModel.frame.time, closeTo(0.65, 1e-9));
    });

    test('clamps to the note', () {
      viewModel
        ..beginSeek()
        ..seekTo(-1);
      expect(viewModel.frame.time, 0);

      viewModel.seekTo(99);
      expect(viewModel.frame.time, viewModel.duration);
    });
  });

  test('settings commands update the shared settings', () {
    viewModel
      ..setInkColor(InkColor.red)
      ..setPaper(PaperBackground.dotGrid)
      ..setShowPenTip(false);

    expect(
      viewModel.settings.value,
      const CanvasSettings(
        inkColor: InkColor.red,
        paper: PaperBackground.dotGrid,
        showPenTip: false,
      ),
    );
  });

  test('dispose disposes the clock', () {
    final ownClock = ManualFrameClock();

    NoteReplayViewModel(
      note: testSummary,
      noteRepository: repository,
      settingsRepository: settings,
      clock: ownClock,
    ).dispose();

    expect(ownClock.disposed, isTrue);
  });
}
