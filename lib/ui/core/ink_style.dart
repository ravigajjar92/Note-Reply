import 'dart:typed_data';
import 'dart:ui';

import '../../domain/models/canvas_settings.dart';

/// Colours, sizes and `Paint` objects for drawing notes.
///
/// Every `Paint` is created once here and shared, so painters never allocate
/// one while painting. Ink sizes are in millimetres because ink is drawn in
/// note space, scaled by the canvas transform.
abstract final class InkStyle {
  /// Ink line width in millimetres.
  static const lineWidth = 0.45;

  static const paperColor = Color(0xFFFFFDF8);
  static const dotColor = Color(0xFFC9C4BA);

  /// Spacing of the dot grid in logical pixels. Fixed on screen, so the grid
  /// looks the same for every note, whatever its size.
  static const dotSpacing = 24.0;

  static Color color(InkColor inkColor) => switch (inkColor) {
    InkColor.black => const Color(0xFF1A1A1A),
    InkColor.blue => const Color(0xFF1E5BD8),
    InkColor.red => const Color(0xFFC62828),
    InkColor.green => const Color(0xFF2E7D32),
    InkColor.purple => const Color(0xFF6A1B9A),
  };

  static String name(InkColor inkColor) => switch (inkColor) {
    InkColor.black => 'Black',
    InkColor.blue => 'Blue',
    InkColor.red => 'Red',
    InkColor.green => 'Green',
    InkColor.purple => 'Purple',
  };

  static final Map<InkColor, Paint> _strokePaints = {
    for (final inkColor in InkColor.values)
      inkColor: _roundPen(color(inkColor), lineWidth),
  };

  static final Map<InkColor, Paint> _penTipPaints = {
    for (final inkColor in InkColor.values)
      inkColor: _roundPen(color(inkColor), lineWidth * 3),
  };

  /// Paint for ink lines.
  static Paint strokePaint(InkColor inkColor) => _strokePaints[inkColor]!;

  /// Paint for the pen tip dot: 1.5 × the line width in radius.
  static Paint penTipPaint(InkColor inkColor) => _penTipPaints[inkColor]!;

  /// Paper-coloured ring drawn under the pen tip so it stands out over ink.
  static final Paint penTipOutlinePaint = _roundPen(
    paperColor,
    lineWidth * 3 + 0.5,
  );

  static final Paint paperPaint = Paint()..color = paperColor;

  /// Grid dots, 1 px in radius. Drawn in screen pixels, not millimetres.
  static final Paint dotPaint = _roundPen(dotColor, 2);

  /// Draws one stroke's interleaved points: a polyline, or a dot when it has
  /// a single point.
  static void drawStroke(Canvas canvas, Float32List points, Paint paint) {
    if (points.length >= 4) {
      canvas.drawRawPoints(PointMode.polygon, points, paint);
    } else if (points.length == 2) {
      canvas.drawRawPoints(PointMode.points, points, paint);
    }
  }

  static Paint _roundPen(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
}
