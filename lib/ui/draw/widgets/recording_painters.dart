import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../domain/models/ink_recording.dart';
import '../../core/ink_style.dart';
import '../view_models/draw_note_view_model.dart';

/// Paints the finished strokes of a recording. Repaints when a stroke ends,
/// on undo and on clear, not while a stroke is drawn.
class RecordedInkPainter extends CustomPainter {
  RecordedInkPainter({
    required this.recording,
    required this.strokeCount,
    required this.ink,
  }) : super(repaint: strokeCount);

  final InkRecording recording;
  final ValueListenable<int> strokeCount;
  final Paint ink;

  @override
  void paint(Canvas canvas, Size size) {
    final count = recording.strokeCount;
    if (count == 0) return;
    canvas
      ..save()
      ..scale(1 / DrawNoteViewModel.mmPerLogicalPixel);
    for (var s = 0; s < count; s++) {
      InkStyle.drawStroke(canvas, recording.strokePoints(s), ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RecordedInkPainter oldDelegate) =>
      oldDelegate.recording != recording ||
      oldDelegate.strokeCount != strokeCount ||
      oldDelegate.ink != ink;
}

/// Paints the stroke being written. Repaints for every new point, drawing
/// only that one stroke.
class LiveInkPainter extends CustomPainter {
  LiveInkPainter({
    required this.recording,
    required this.activeStroke,
    required this.ink,
  }) : super(repaint: activeStroke);

  final InkRecording recording;
  final Listenable activeStroke;
  final Paint ink;

  @override
  void paint(Canvas canvas, Size size) {
    final points = recording.activePoints;
    if (points.isEmpty) return;
    canvas
      ..save()
      ..scale(1 / DrawNoteViewModel.mmPerLogicalPixel);
    InkStyle.drawStroke(canvas, points, ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiveInkPainter oldDelegate) =>
      oldDelegate.recording != recording ||
      oldDelegate.activeStroke != activeStroke ||
      oldDelegate.ink != ink;
}
