import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import '../../core/ink_style.dart';
import '../view_models/note_geometry.dart';
import '../view_models/replay_frame.dart';
import 'replay_canvas.dart';

/// Paints the stroke being written at the playback time, and the pen tip.
///
/// Repaints every frame while playing, but draws only one partial stroke:
/// a view of its samples so far plus the segment to the pen position.
class ActiveInkPainter extends CustomPainter {
  ActiveInkPainter({
    required this.geometry,
    required this.frame,
    required this.viewport,
    required this.ink,
    required this.penTip,
    required this.showPenTip,
  }) : super(repaint: frame);

  final NoteGeometry geometry;
  final ReplayFrame frame;
  final ViewportTransform viewport;
  final Paint ink;
  final Paint penTip;
  final bool showPenTip;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = frame.activeStroke;
    if (stroke < 0) return;
    canvas
      ..save()
      ..translate(viewport.dx, viewport.dy)
      ..scale(viewport.scale);

    final note = geometry.note;
    final start = note.strokeStart[stroke];
    final visible = Float32List.sublistView(
      note.xy,
      start * 2,
      frame.visibleEnd * 2,
    );
    if (frame.hasHead) {
      if (visible.length >= 4) {
        canvas.drawRawPoints(PointMode.polygon, visible, ink);
      }
      canvas.drawRawPoints(PointMode.lines, frame.headSegment, ink);
    } else {
      InkStyle.drawStroke(canvas, visible, ink);
    }

    if (showPenTip && frame.penDown) {
      canvas
        ..drawRawPoints(
          PointMode.points,
          frame.penPoint,
          InkStyle.penTipOutlinePaint,
        )
        ..drawRawPoints(PointMode.points, frame.penPoint, penTip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ActiveInkPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.frame != frame ||
      oldDelegate.viewport != viewport ||
      oldDelegate.ink != ink ||
      oldDelegate.penTip != penTip ||
      oldDelegate.showPenTip != showPenTip;
}
