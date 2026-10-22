import 'package:flutter/foundation.dart';

/// What the canvas shows at one playback time.
///
/// One instance is reused for the whole replay: `ReplayCursor` overwrites its
/// fields and the ViewModel calls [markChanged] once per frame. The painters
/// listen to it and only read it.
final class ReplayFrame extends ChangeNotifier {
  /// Playback time in seconds.
  double time = 0;

  /// Number of strokes finished by [time].
  int committedCount = 0;

  /// The stroke the pen is drawing at [time], or -1 when the pen is up.
  int activeStroke = -1;

  /// One past the index of the last sample at or before [time] in
  /// [activeStroke].
  int visibleEnd = 0;

  /// Whether [headSegment] holds the partial segment from the last sample to
  /// the pen position.
  bool hasHead = false;

  /// `x0, y0, x1, y1` of the partial segment, in millimetres.
  final Float32List headSegment = Float32List(4);

  /// Whether the pen is touching the paper at [time].
  bool penDown = false;

  /// `x, y` of the pen position, in millimetres.
  final Float32List penPoint = Float32List(2);

  /// While the pen is down: seconds from the current sample to the next one
  /// in the stroke. -1 otherwise.
  double writingInterval = -1;

  /// While the pen is up between strokes: seconds from the last sample of
  /// the previous stroke to the first sample of the next. -1 otherwise.
  double liftInterval = -1;

  /// Tells the painters to repaint.
  void markChanged() => notifyListeners();
}
