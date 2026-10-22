import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/canvas_settings_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/canvas_settings.dart';
import '../../../domain/models/ink_recording.dart';
import '../../../domain/models/note_summary.dart';
import '../../../utils/result.dart';

/// ViewModel for the New note screen: records what the user writes and
/// turns it into a note.
///
/// Pointer moves fire only [activeStroke], which the live-ink painter
/// listens to; nothing that rebuilds widgets changes while a stroke is drawn.
class DrawNoteViewModel {
  DrawNoteViewModel({
    required this._noteRepository,
    required this._settingsRepository,
  });

  /// Converts logical pixels to millimetres, taking a logical pixel as
  /// 1/160 inch (Flutter's reference density).
  static const mmPerLogicalPixel = 25.4 / 160;

  final NoteRepository _noteRepository;
  final CanvasSettingsRepository _settingsRepository;

  /// What has been written so far, in millimetres and seconds.
  final recording = InkRecording();

  final _strokeCount = ValueNotifier(0);
  final _hasInk = ValueNotifier(false);
  final _activeStroke = _Signal();

  /// The pointer drawing the current stroke. Other pointers are ignored, so
  /// a resting palm doesn't draw.
  int? _pointer;

  /// Number of finished strokes. Changes when a stroke ends, on undo, and on
  /// clear.
  ValueListenable<int> get strokeCount => _strokeCount;

  /// Whether anything has been written, including a stroke in progress.
  ValueListenable<bool> get hasInk => _hasInk;

  /// Fires for every point added to the stroke being written.
  Listenable get activeStroke => _activeStroke;

  ValueListenable<CanvasSettings> get settings => _settingsRepository.settings;

  /// A pointer touched the canvas at [position] (logical pixels).
  void penDown(int pointer, Offset position, Duration timeStamp) {
    if (_pointer != null) return;
    _pointer = pointer;
    recording.beginStroke(
      position.dx * mmPerLogicalPixel,
      position.dy * mmPerLogicalPixel,
      _seconds(timeStamp),
    );
    _hasInk.value = true;
    _activeStroke.fire();
  }

  /// The drawing pointer moved to [position] (logical pixels).
  void penMove(int pointer, Offset position, Duration timeStamp) {
    if (pointer != _pointer) return;
    recording.addPoint(
      position.dx * mmPerLogicalPixel,
      position.dy * mmPerLogicalPixel,
      _seconds(timeStamp),
    );
    _activeStroke.fire();
  }

  /// The drawing pointer lifted, or the system cancelled it.
  void penUp(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    recording.endStroke();
    _sync();
  }

  /// Removes the last stroke.
  void undo() {
    _pointer = null;
    recording.undo();
    _sync();
  }

  /// Removes everything written.
  void clear() {
    _pointer = null;
    recording.clear();
    _sync();
  }

  /// Saves what was written as a new note and returns its summary, or the
  /// error if saving failed (the writing is kept, so the user can try again).
  /// Call only when [strokeCount] is above zero.
  Future<Result<NoteSummary>> finish() {
    recording.endStroke();
    return _noteRepository.addDrawnNote(recording);
  }

  void _sync() {
    _strokeCount.value = recording.strokeCount;
    _hasInk.value = !recording.isEmpty;
    _activeStroke.fire();
  }

  static double _seconds(Duration timeStamp) =>
      timeStamp.inMicroseconds / Duration.microsecondsPerSecond;

  void dispose() {
    _strokeCount.dispose();
    _hasInk.dispose();
    _activeStroke.dispose();
  }
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
