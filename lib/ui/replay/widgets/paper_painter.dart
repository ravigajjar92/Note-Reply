import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';

import '../../../domain/models/canvas_settings.dart';
import '../../core/ink_style.dart';

/// Paints the paper: blank, or with a dot grid.
///
/// The grid uses a fixed on-screen spacing, so every note gets the same paper
/// whatever its size. Repaints only when the canvas size or paper setting
/// changes, never during playback.
class PaperPainter extends CustomPainter {
  PaperPainter({required this.paper});

  final PaperBackground paper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, InkStyle.paperPaint);
    if (paper != PaperBackground.dotGrid) return;
    canvas.drawRawPoints(
      PointMode.points,
      dotPositions(size),
      InkStyle.dotPaint,
    );
  }

  /// Interleaved `x, y` positions of the grid dots for a canvas of [size]:
  /// every [InkStyle.dotSpacing] pixels, centred so the margins on opposite
  /// edges are equal.
  static Float32List dotPositions(Size size) {
    const step = InkStyle.dotSpacing;
    if (size.width <= 0 || size.height <= 0) return Float32List(0);
    final columns = (size.width / step).floor() + 1;
    final rows = (size.height / step).floor() + 1;
    final firstX = (size.width - (columns - 1) * step) / 2;
    final firstY = (size.height - (rows - 1) * step) / 2;

    final dots = Float32List(columns * rows * 2);
    var i = 0;
    for (var row = 0; row < rows; row++) {
      final y = firstY + row * step;
      for (var column = 0; column < columns; column++) {
        dots[i++] = firstX + column * step;
        dots[i++] = y;
      }
    }
    return dots;
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) => oldDelegate.paper != paper;
}
