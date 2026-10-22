import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/ui/core/ink_style.dart';
import 'package:note_replay_animation/ui/replay/widgets/paper_painter.dart';

void main() {
  const step = InkStyle.dotSpacing;

  List<double> xs(Float32List dots) => [
    for (var i = 0; i < dots.length; i += 2) dots[i],
  ];
  List<double> ys(Float32List dots) => [
    for (var i = 1; i < dots.length; i += 2) dots[i],
  ];

  test('dots are a fixed distance apart, whatever the canvas size', () {
    for (final size in const [Size(400, 700), Size(1200, 800), Size(90, 50)]) {
      final dots = PaperPainter.dotPositions(size);
      final columns = xs(dots).toSet().toList()..sort();
      final rows = ys(dots).toSet().toList()..sort();

      for (var i = 1; i < columns.length; i++) {
        expect(columns[i] - columns[i - 1], closeTo(step, 1e-3));
      }
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i] - rows[i - 1], closeTo(step, 1e-3));
      }
      expect(dots.length, columns.length * rows.length * 2);
    }
  });

  test('the grid is centred, with equal margins on opposite edges', () {
    const size = Size(410, 700);
    final dots = PaperPainter.dotPositions(size);
    final x = xs(dots);
    final y = ys(dots);
    final minX = x.reduce((a, b) => a < b ? a : b);
    final maxX = x.reduce((a, b) => a > b ? a : b);
    final minY = y.reduce((a, b) => a < b ? a : b);
    final maxY = y.reduce((a, b) => a > b ? a : b);

    expect(minX, closeTo(size.width - maxX, 1e-3));
    expect(minY, closeTo(size.height - maxY, 1e-3));
    expect(minX, inInclusiveRange(0, step / 2));
  });

  test('a larger canvas gets more dots, never denser ones', () {
    final small = PaperPainter.dotPositions(const Size(240, 240));
    final large = PaperPainter.dotPositions(const Size(480, 480));

    // 11 × 11 dots on 240 px, 21 × 21 on 480 px: same 24 px spacing.
    expect(small.length ~/ 2, 11 * 11);
    expect(large.length ~/ 2, 21 * 21);
  });

  test('an empty canvas has no dots', () {
    expect(PaperPainter.dotPositions(Size.zero), isEmpty);
  });
}
