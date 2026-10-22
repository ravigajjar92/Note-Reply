import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../view_models/replay_frame.dart';

/// A draggable progress bar with the `elapsed / total` time.
///
/// The bar is painted and repaints every frame from [frame] without
/// rebuilding. The time label and the slider semantics rebuild from
/// [clockTenths], at most 10 times a second.
class ReplayProgressBar extends StatelessWidget {
  const ReplayProgressBar({
    super.key,
    required this.frame,
    required this.clockTenths,
    required this.duration,
    required this.onSeekStart,
    required this.onSeek,
    required this.onSeekEnd,
  });

  final ReplayFrame frame;
  final ValueListenable<int> clockTenths;

  /// Length of the note in seconds.
  final double duration;

  final VoidCallback onSeekStart;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;

  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = formatPlaybackTime(duration);

    final bar = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double timeAt(double x) =>
            width <= 0 ? 0 : (x / width).clamp(0.0, 1.0) * duration;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            onSeekStart();
            onSeek(timeAt(details.localPosition.dx));
          },
          onHorizontalDragUpdate: (details) =>
              onSeek(timeAt(details.localPosition.dx)),
          onHorizontalDragEnd: (_) => onSeekEnd(),
          onHorizontalDragCancel: onSeekEnd,
          onTapUp: (details) {
            onSeekStart();
            onSeek(timeAt(details.localPosition.dx));
            onSeekEnd();
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(width, _height),
              painter: _ProgressPainter(
                frame: frame,
                duration: duration,
                trackColor: colors.outlineVariant,
                playedColor: colors.primary,
              ),
            ),
          ),
        );
      },
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: ValueListenableBuilder(
          valueListenable: clockTenths,
          builder: (context, tenths, bar) {
            final elapsed = tenths / 10;
            void seekBy(double delta) {
              onSeekStart();
              onSeek((elapsed + delta).clamp(0.0, duration));
              onSeekEnd();
            }

            return Row(
              children: [
                Expanded(
                  child: Semantics(
                    slider: true,
                    label: 'Playback position',
                    value: '${formatPlaybackTime(elapsed)} of $total',
                    onIncrease: () => seekBy(duration / 10),
                    onDecrease: () => seekBy(-duration / 10),
                    child: bar,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${formatPlaybackTime(elapsed)} / $total',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
          child: bar,
        ),
      ),
    );
  }
}

/// Formats [seconds] as `m:ss`.
String formatPlaybackTime(double seconds) {
  final whole = seconds.floor();
  return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.frame,
    required this.duration,
    required this.trackColor,
    required this.playedColor,
  }) : _track = _line(trackColor, 4),
       _played = _line(playedColor, 4),
       _thumb = _line(playedColor, 16),
       super(repaint: frame);

  final ReplayFrame frame;
  final double duration;
  final Color trackColor;
  final Color playedColor;

  final Paint _track;
  final Paint _played;
  final Paint _thumb;

  // Reused every frame, so painting allocates nothing.
  final _segment = Float32List(4);
  final _point = Float32List(2);

  static const _inset = 8.0;

  static Paint _line(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final left = _inset;
    final right = size.width - _inset;
    if (right <= left) return;
    final fraction = duration <= 0 ? 1.0 : frame.time / duration;
    final x = left + (right - left) * fraction.clamp(0.0, 1.0);

    _segment
      ..[0] = left
      ..[1] = y
      ..[2] = right
      ..[3] = y;
    canvas.drawRawPoints(PointMode.lines, _segment, _track);
    _segment[2] = x;
    canvas.drawRawPoints(PointMode.lines, _segment, _played);
    _point
      ..[0] = x
      ..[1] = y;
    canvas.drawRawPoints(PointMode.points, _point, _thumb);
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.duration != duration ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.playedColor != playedColor;
}
