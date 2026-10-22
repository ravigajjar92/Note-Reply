import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/models/canvas_settings.dart';
import '../../core/ink_style.dart';
import '../view_models/note_geometry.dart';
import '../view_models/replay_frame.dart';
import 'active_ink_painter.dart';
import 'committed_ink_painter.dart';
import 'note_stats_panel.dart';
import 'paper_painter.dart';

/// Scales and centres note space (millimetres) into the canvas (pixels).
///
/// Applied once per paint as a canvas transform, so points are never
/// transformed on the CPU. Equal transforms compare equal, so painters skip
/// repainting when a rebuild doesn't change the layout.
@immutable
final class ViewportTransform {
  const ViewportTransform({
    required this.scale,
    required this.dx,
    required this.dy,
  });

  /// Fits a [contentWidth] × [contentHeight] mm note inside [size], minus
  /// [padding], centred.
  factory ViewportTransform.fit({
    required Size size,
    required double contentWidth,
    required double contentHeight,
    required EdgeInsets padding,
  }) {
    final availableWidth = math.max(0.0, size.width - padding.horizontal);
    final availableHeight = math.max(0.0, size.height - padding.vertical);
    // A note can be a single dot; keep the scale finite.
    final width = math.max(contentWidth, 1.0);
    final height = math.max(contentHeight, 1.0);
    final scale = math.min(
      math.min(availableWidth / width, availableHeight / height),
      maxScale,
    );
    return ViewportTransform(
      scale: scale,
      dx: padding.left + (availableWidth - contentWidth * scale) / 2,
      dy: padding.top + (availableHeight - contentHeight * scale) / 2,
    );
  }

  /// Largest zoom when fitting, in pixels per millimetre, so a tiny note
  /// (a single word, or a dot) isn't blown up to fill the canvas.
  static const maxScale = 20.0;

  /// Pixels per millimetre.
  final double scale;
  final double dx;
  final double dy;

  @override
  bool operator ==(Object other) =>
      other is ViewportTransform &&
      other.scale == scale &&
      other.dx == dx &&
      other.dy == dy;

  @override
  int get hashCode => Object.hash(scale, dx, dy);
}

/// The replay canvas: paper, finished ink, and the stroke being written,
/// each in its own layer so playback repaints only the top one. A stats panel
/// sits in a band along the bottom; the ink is fitted above it.
class ReplayCanvas extends StatelessWidget {
  const ReplayCanvas({
    super.key,
    required this.geometry,
    required this.frame,
    required this.committedStrokes,
    required this.settings,
    required this.semanticLabel,
    required this.penWritingMicros,
    required this.penLiftMicros,
  });

  /// Space around the ink, inside the area above the stats band.
  static const inkPadding = EdgeInsets.all(16);

  /// The floating button takes 56 dp plus a 16 dp margin at the bottom
  /// right. The stats band is at least this tall, so the button never covers
  /// ink, and leaves this much room on its right for the button.
  static const _floatingButtonExtent = 56.0 + 16.0;

  final NoteGeometry geometry;
  final ReplayFrame frame;
  final ValueListenable<int> committedStrokes;
  final CanvasSettings settings;
  final String semanticLabel;
  final ValueListenable<int?> penWritingMicros;
  final ValueListenable<int?> penLiftMicros;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: PaperPainter(paper: settings.paper)),
          ),
          Column(
            children: [
              Expanded(child: _buildInk()),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _floatingButtonExtent,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16 + _floatingButtonExtent,
                    16,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    heightFactor: 1,
                    child: NoteStatsPanel(
                      note: geometry.note,
                      canvasSize: constraints.biggest,
                      penWritingMicros: penWritingMicros,
                      penLiftMicros: penLiftMicros,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInk() {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = ViewportTransform.fit(
            size: constraints.biggest,
            contentWidth: geometry.note.width,
            contentHeight: geometry.note.height,
            padding: inkPadding,
          );
          final ink = InkStyle.strokePaint(settings.inkColor);
          return Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: CommittedInkPainter(
                    geometry: geometry,
                    committedStrokes: committedStrokes,
                    viewport: viewport,
                    ink: ink,
                  ),
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: ActiveInkPainter(
                    geometry: geometry,
                    frame: frame,
                    viewport: viewport,
                    ink: ink,
                    penTip: InkStyle.penTipPaint(settings.inkColor),
                    showPenTip: settings.showPenTip,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
