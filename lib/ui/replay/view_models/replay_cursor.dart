import 'dart:typed_data';

import '../../../domain/models/note.dart';
import 'replay_frame.dart';

/// Finds what is drawn at a playback time, without scanning the whole note.
///
/// Moving forward continues from the previous position, so a whole replay
/// costs O(points) in total. Moving backward uses binary search.
final class ReplayCursor {
  ReplayCursor(this._note);

  final Note _note;
  double _time = double.negativeInfinity;

  /// First stroke not finished by [_time]; equals the committed count.
  int _stroke = 0;

  /// Last sample at or before [_time] in the active stroke.
  int _point = 0;

  /// Writes the state at playback [time] into [frame].
  void moveTo(double time, ReplayFrame frame) {
    final note = _note;
    final strokeCount = note.strokeCount;
    final backwards = time < _time;

    if (backwards) {
      _stroke = _upperBound(note.strokeT1, time, 0, strokeCount);
    } else {
      while (_stroke < strokeCount && note.strokeT1[_stroke] <= time) {
        _stroke++;
      }
    }
    _time = time;
    frame
      ..time = time
      ..committedCount = _stroke;

    if (_stroke >= strokeCount || note.strokeT0[_stroke] > time) {
      // Pen up: between strokes, or after the last one.
      final betweenStrokes = _stroke > 0 && _stroke < strokeCount;
      frame
        ..activeStroke = -1
        ..hasHead = false
        ..penDown = false
        ..writingInterval = -1
        ..liftInterval = betweenStrokes
            ? note.strokeT0[_stroke] - note.strokeT1[_stroke - 1]
            : -1;
      return;
    }

    final start = note.strokeStart[_stroke];
    final end = note.strokeStart[_stroke + 1];
    final t = note.t;
    var i = backwards || _point < start
        ? _upperBound(t, time, start, end) - 1
        : _point;
    while (i + 1 < end && t[i + 1] <= time) {
      i++;
    }
    _point = i;

    final xy = note.xy;
    final x0 = xy[i * 2];
    final y0 = xy[i * 2 + 1];
    frame
      ..activeStroke = _stroke
      ..visibleEnd = i + 1
      ..penDown = true
      ..writingInterval = i + 1 < end ? t[i + 1] - t[i] : -1
      ..liftInterval = -1;

    if (i + 1 < end && time > t[i]) {
      // Pen position between two samples, so it moves smoothly between them.
      final f = (time - t[i]) / (t[i + 1] - t[i]);
      final x = x0 + (xy[i * 2 + 2] - x0) * f;
      final y = y0 + (xy[i * 2 + 3] - y0) * f;
      frame
        ..hasHead = true
        ..headSegment[0] = x0
        ..headSegment[1] = y0
        ..headSegment[2] = x
        ..headSegment[3] = y
        ..penPoint[0] = x
        ..penPoint[1] = y;
    } else {
      frame
        ..hasHead = false
        ..penPoint[0] = x0
        ..penPoint[1] = y0;
    }
  }

  /// First index in `[lo, hi)` whose value is greater than [value], or [hi].
  static int _upperBound(Float64List values, double value, int lo, int hi) {
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (values[mid] <= value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
