import '../../domain/models/note.dart';

/// Writes a [Note] in the pen-export CSV format that `NoteCsvParser` reads:
/// columns `x`, `y`, `t` and `stroke`, positions in metres, times in seconds.
///
/// Numbers are written at full precision, unlike the pen's export, which
/// rounds times to 6 significant digits.
abstract final class NoteCsvWriter {
  static const _millimetresPerMetre = 1000;

  static String write(Note note) {
    final buffer = StringBuffer('x,y,t,stroke\n');
    for (var s = 0; s < note.strokeCount; s++) {
      for (var i = note.strokeStart[s]; i < note.strokeStart[s + 1]; i++) {
        buffer
          ..write(note.xy[i * 2] / _millimetresPerMetre)
          ..write(',')
          ..write(note.xy[i * 2 + 1] / _millimetresPerMetre)
          ..write(',')
          ..write(note.t[i])
          ..write(',')
          ..write(s)
          ..write('\n');
      }
    }
    return buffer.toString();
  }
}
