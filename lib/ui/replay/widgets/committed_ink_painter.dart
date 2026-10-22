import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/ink_style.dart';
import '../view_models/note_geometry.dart';
import 'replay_canvas.dart';

/// Paints the strokes finished by the current playback time.
///
/// Repaints when the finished-stroke count changes (about once per stroke),
/// not every frame.
class CommittedInkPainter extends CustomPainter {
  CommittedInkPainter({
    required this.geometry,
    required this.committedStrokes,
    required this.viewport,
    required this.ink,
  }) : super(repaint: committedStrokes);

  final NoteGeometry geometry;
  final ValueListenable<int> committedStrokes;
  final ViewportTransform viewport;
  final Paint ink;

  @override
  void paint(Canvas canvas, Size size) {
    final count = committedStrokes.value;
    if (count == 0) return;
    canvas
      ..save()
      ..translate(viewport.dx, viewport.dy)
      ..scale(viewport.scale);
    final strokes = geometry.strokes;
    for (var s = 0; s < count; s++) {
      InkStyle.drawStroke(canvas, strokes[s], ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CommittedInkPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.committedStrokes != committedStrokes ||
      oldDelegate.viewport != viewport ||
      oldDelegate.ink != ink;
}
