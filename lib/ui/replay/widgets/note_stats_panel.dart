import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/note.dart';

/// Facts about the note, shown at the bottom of the canvas: point and stroke
/// counts, canvas size, and the live time from the current point to the next.
///
/// The counts and size rebuild only when the note loads or the canvas
/// resizes. The two timings are separate leaves that rebuild only when their
/// value changes, never the panel.
class NoteStatsPanel extends StatelessWidget {
  const NoteStatsPanel({
    super.key,
    required this.note,
    required this.canvasSize,
    required this.penWritingMicros,
    required this.penLiftMicros,
  });

  final Note note;

  /// Size of the whole canvas, in logical pixels.
  final Size canvasSize;

  /// While the pen is down: microseconds from the current point to the next.
  final ValueListenable<int?> penWritingMicros;

  /// While the pen is up: microseconds from the last point of the previous
  /// stroke to the first point of the next.
  final ValueListenable<int?> penLiftMicros;

  @override
  Widget build(BuildContext context) {
    final width = canvasSize.width.round();
    final height = canvasSize.height.round();
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _Stat('Points', formatCount(note.pointCount)),
        _Stat('Strokes', formatCount(note.strokeCount)),
        _Stat('Canvas', '$width × $height px'),
        _LiveStat('Pen writing', penWritingMicros),
        _LiveStat('Pen lift', penLiftMicros),
      ],
    );
  }
}

/// Formats [count] with thousands separators: `3788` → `3,788`.
String formatCount(int count) {
  final digits = count.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats [micros] as milliseconds with two decimals: `2433` → `2.43 ms`.
/// Null, meaning there's no current interval, shows as `—`.
String formatMillis(int? micros) =>
    micros == null ? '—' : '${(micros / 1000).toStringAsFixed(2)} ms';

class _LiveStat extends StatelessWidget {
  const _LiveStat(this.label, this.micros);

  final String label;
  final ValueListenable<int?> micros;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: micros,
      builder: (context, micros, _) => _Stat(label, formatMillis(micros)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: theme.textTheme.bodySmall,
    );
  }
}
