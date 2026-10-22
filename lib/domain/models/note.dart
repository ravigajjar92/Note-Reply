import 'dart:typed_data';

/// An immutable handwritten note, stored as typed arrays so it can be drawn
/// without per-point objects.
///
/// All coordinates are in millimetres, with the top-left of the ink bounds at
/// (0, 0). Times are seconds from the first sample. Points are in recording
/// order, and the points of stroke `s` are the range
/// `[strokeStart[s], strokeStart[s + 1])`.
final class Note {
  Note({
    required this.id,
    required this.xy,
    required this.t,
    required this.strokeStart,
    required this.strokeT0,
    required this.strokeT1,
    required this.width,
    required this.height,
  }) : assert(xy.length == t.length * 2),
       assert(strokeStart.length == strokeT0.length + 1),
       assert(strokeT0.length == strokeT1.length);

  /// The note's id, matching its `NoteSummary.id`.
  final String id;

  /// Interleaved point coordinates `x0, y0, x1, y1, …` in millimetres.
  final Float32List xy;

  /// Time of each point in seconds from the first sample.
  final Float64List t;

  /// Index of each stroke's first point, plus a final entry equal to
  /// [pointCount].
  final Int32List strokeStart;

  /// Time of each stroke's first point.
  final Float64List strokeT0;

  /// Time of each stroke's last point.
  final Float64List strokeT1;

  /// Width of the ink bounds in millimetres.
  final double width;

  /// Height of the ink bounds in millimetres.
  final double height;

  /// Number of strokes.
  int get strokeCount => strokeT0.length;

  /// Number of points.
  int get pointCount => t.length;

  /// Time of the last point, in seconds.
  double get duration => t.last;
}
