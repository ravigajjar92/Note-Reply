import 'dart:typed_data';

import 'note.dart';

/// Pen samples captured while the user writes on the canvas.
///
/// Positions are in millimetres from the canvas's top-left, times in seconds.
/// Points go into growable typed buffers, so recording a stroke doesn't
/// allocate an object per point. [toNote] normalises the samples the same way
/// the CSV parser does, so a drawn note replays like a bundled one.
final class InkRecording {
  final _strokes = <_Stroke>[];
  _StrokeBuffer? _active;
  double _lastTime = double.negativeInfinity;

  static final _noPoints = Float32List(0);

  /// Number of finished strokes.
  int get strokeCount => _strokes.length;

  /// Whether nothing has been written, including a stroke in progress.
  bool get isEmpty => _strokes.isEmpty && _active == null;

  /// Interleaved `x, y` points of finished stroke [index], in millimetres.
  Float32List strokePoints(int index) => _strokes[index].xy;

  /// Interleaved `x, y` points of the stroke being written, or none.
  Float32List get activePoints => _active?.points ?? _noPoints;

  /// Starts a stroke at ([x], [y]) mm. Finishes any stroke in progress.
  void beginStroke(double x, double y, double time) {
    endStroke();
    _active = _StrokeBuffer()..add(x, y, _monotonic(time));
  }

  /// Adds a point to the stroke being written. Ignored when there isn't one.
  void addPoint(double x, double y, double time) =>
      _active?.add(x, y, _monotonic(time));

  /// Finishes the stroke being written, if any.
  void endStroke() {
    final active = _active;
    if (active == null) return;
    _strokes.add(active.finish());
    _active = null;
  }

  /// Removes the stroke being written, or else the last finished stroke.
  void undo() {
    if (_active != null) {
      _active = null;
    } else if (_strokes.isNotEmpty) {
      _strokes.removeLast();
    }
  }

  void clear() {
    _strokes.clear();
    _active = null;
  }

  /// The finished strokes as a [Note]: positions moved so the ink's top-left
  /// is (0, 0), and times so the first sample is at 0.
  ///
  /// Throws a [StateError] when no stroke has been finished.
  Note toNote(String id) {
    if (_strokes.isEmpty) throw StateError('Nothing has been written.');

    var count = 0;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final stroke in _strokes) {
      count += stroke.t.length;
      for (var i = 0; i < stroke.xy.length; i += 2) {
        final x = stroke.xy[i];
        final y = stroke.xy[i + 1];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    final t0 = _strokes.first.t[0];
    final xy = Float32List(count * 2);
    final t = Float64List(count);
    final strokeStart = Int32List(_strokes.length + 1);
    final strokeT0 = Float64List(_strokes.length);
    final strokeT1 = Float64List(_strokes.length);
    var p = 0;
    for (var s = 0; s < _strokes.length; s++) {
      final stroke = _strokes[s];
      strokeStart[s] = p;
      strokeT0[s] = stroke.t.first - t0;
      strokeT1[s] = stroke.t.last - t0;
      for (var i = 0; i < stroke.t.length; i++, p++) {
        xy[p * 2] = stroke.xy[i * 2] - minX;
        xy[p * 2 + 1] = stroke.xy[i * 2 + 1] - minY;
        t[p] = stroke.t[i] - t0;
      }
    }
    strokeStart[_strokes.length] = count;

    return Note(
      id: id,
      xy: xy,
      t: t,
      strokeStart: strokeStart,
      strokeT0: strokeT0,
      strokeT1: strokeT1,
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  /// Keeps time from going backwards, which replay relies on.
  double _monotonic(double time) {
    if (time < _lastTime) return _lastTime;
    return _lastTime = time;
  }
}

final class _Stroke {
  const _Stroke(this.xy, this.t);

  final Float32List xy;
  final Float64List t;
}

/// A stroke being written: typed buffers that double in size as they fill.
final class _StrokeBuffer {
  var _xy = Float32List(256);
  var _t = Float64List(128);
  var _count = 0;

  Float32List get points => Float32List.sublistView(_xy, 0, _count * 2);

  void add(double x, double y, double time) {
    if (_count == _t.length) {
      _xy = Float32List(_xy.length * 2)..setAll(0, _xy);
      _t = Float64List(_t.length * 2)..setAll(0, _t);
    }
    _xy[_count * 2] = x;
    _xy[_count * 2 + 1] = y;
    _t[_count] = time;
    _count++;
  }

  _Stroke finish() =>
      _Stroke(_xy.sublist(0, _count * 2), _t.sublist(0, _count));
}
