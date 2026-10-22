import 'package:flutter/foundation.dart';

import '../../../data/repositories/canvas_settings_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/canvas_settings.dart';
import '../../../domain/models/note_summary.dart';
import '../../../utils/result.dart';
import 'frame_clock.dart';
import 'note_geometry.dart';
import 'replay_cursor.dart';
import 'replay_frame.dart';
import 'replay_timeline.dart';

/// Whether the note is loading, ready to draw, or failed to load.
sealed class NoteLoadState {
  const NoteLoadState();
}

final class NoteLoading extends NoteLoadState {
  const NoteLoading();
}

final class NoteReady extends NoteLoadState {
  const NoteReady(this.geometry);

  final NoteGeometry geometry;
}

final class NoteLoadError extends NoteLoadState {
  const NoteLoadError(this.error);

  final Exception error;
}

/// Where playback is.
enum PlaybackStatus {
  /// Showing the complete note, before the first replay.
  ready,
  playing,
  paused,

  /// Showing the complete note after a replay finished.
  completed,
}

/// ViewModel for the Note detail screen: loads the note, runs playback and
/// changes canvas settings.
///
/// Each kind of change has its own listenable, so a widget only hears the
/// updates it needs. Only [frame] fires every display frame; nothing here
/// that rebuilds widgets does.
class NoteReplayViewModel {
  NoteReplayViewModel({
    required this.note,
    required this._noteRepository,
    required this._settingsRepository,
    required this._clock,
  });

  /// The note being shown.
  final NoteSummary note;

  final NoteRepository _noteRepository;
  final CanvasSettingsRepository _settingsRepository;
  final FrameClock _clock;

  final _loadState = ValueNotifier<NoteLoadState>(const NoteLoading());
  final _status = ValueNotifier(PlaybackStatus.ready);
  final _committedStrokes = ValueNotifier(0);
  final _clockTenths = ValueNotifier(0);
  final _penWritingMicros = ValueNotifier<int?>(null);
  final _penLiftMicros = ValueNotifier<int?>(null);

  /// The per-frame snapshot. Fires every display frame while playing.
  final frame = ReplayFrame();

  ReplayCursor? _cursor;
  ReplayTimeline? _timeline;
  double _duration = 0;
  bool _resumeAfterSeek = false;
  bool _disposed = false;

  ValueListenable<NoteLoadState> get loadState => _loadState;
  ValueListenable<PlaybackStatus> get status => _status;

  /// Number of finished strokes. Changes about once per stroke.
  ValueListenable<int> get committedStrokes => _committedStrokes;

  /// Playback time in tenths of a second. Changes at most 10 times a second.
  ValueListenable<int> get clockTenths => _clockTenths;

  /// While the pen is down: microseconds from the current point to the next
  /// one in the stroke. Null otherwise. Changes only when the value does.
  ValueListenable<int?> get penWritingMicros => _penWritingMicros;

  /// While the pen is up between strokes: microseconds from the previous
  /// stroke's last point to the next stroke's first point. Null otherwise.
  ValueListenable<int?> get penLiftMicros => _penLiftMicros;

  ValueListenable<CanvasSettings> get settings => _settingsRepository.settings;

  /// Length of the note in seconds, or 0 until it loads.
  double get duration => _duration;

  /// Loads the note and shows it complete, or starts playing it when
  /// [autoPlay] is true. Called when the screen opens, and again by Retry.
  Future<void> load({bool autoPlay = false}) async {
    _loadState.value = const NoteLoading();
    final result = await _noteRepository.loadNote(note.id);
    if (_disposed) return;
    switch (result) {
      case Ok(value: final loaded):
        _cursor = ReplayCursor(loaded);
        _timeline = ReplayTimeline(duration: loaded.duration);
        _duration = loaded.duration;
        _status.value = PlaybackStatus.ready;
        _show(loaded.duration);
        _loadState.value = NoteReady(NoteGeometry(loaded));
        if (autoPlay) togglePlayback();
      case Error(:final error):
        _loadState.value = NoteLoadError(error);
    }
  }

  /// The floating button: plays from the start, pauses, or resumes.
  void togglePlayback() {
    if (_cursor == null) return;
    switch (_status.value) {
      case PlaybackStatus.ready || PlaybackStatus.completed:
        _playFrom(0);
      case PlaybackStatus.playing:
        _clock.stop();
        _status.value = PlaybackStatus.paused;
      case PlaybackStatus.paused:
        _playFrom(frame.time);
    }
  }

  /// Starts dragging the progress bar: pauses until [endSeek].
  void beginSeek() {
    if (_cursor == null) return;
    _resumeAfterSeek = _status.value == PlaybackStatus.playing;
    _clock.stop();
    _status.value = PlaybackStatus.paused;
  }

  /// Shows the note at playback [time], in seconds.
  void seekTo(double time) {
    if (_cursor == null) return;
    _show(time < 0 ? 0 : (time > _duration ? _duration : time));
  }

  /// Stops dragging the progress bar: resumes if it was playing.
  void endSeek() {
    if (!_resumeAfterSeek) return;
    _resumeAfterSeek = false;
    _playFrom(frame.time);
  }

  void setInkColor(InkColor inkColor) =>
      _settingsRepository.setInkColor(inkColor);

  void setPaper(PaperBackground paper) => _settingsRepository.setPaper(paper);

  void setShowPenTip(bool showPenTip) =>
      _settingsRepository.setShowPenTip(showPenTip);

  void _playFrom(double time) {
    _clock.stop();
    _timeline!.anchor(time, Duration.zero);
    _show(time);
    _status.value = PlaybackStatus.playing;
    _clock.start(_onTick);
  }

  void _onTick(Duration elapsed) {
    final time = _timeline!.timeAt(elapsed);
    _show(time);
    if (time >= _duration) {
      _clock.stop();
      _status.value = PlaybackStatus.completed;
    }
  }

  void _show(double time) {
    _cursor!.moveTo(time, frame);
    _committedStrokes.value = frame.committedCount;
    _clockTenths.value = (time * 10).floor();
    _penWritingMicros.value = _micros(frame.writingInterval);
    _penLiftMicros.value = _micros(frame.liftInterval);
    frame.markChanged();
  }

  static int? _micros(double seconds) =>
      seconds < 0 ? null : (seconds * Duration.microsecondsPerSecond).round();

  void dispose() {
    _disposed = true;
    _clock.dispose();
    _loadState.dispose();
    _status.dispose();
    _committedStrokes.dispose();
    _clockTenths.dispose();
    _penWritingMicros.dispose();
    _penLiftMicros.dispose();
    frame.dispose();
  }
}
