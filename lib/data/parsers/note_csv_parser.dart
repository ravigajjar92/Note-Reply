import 'dart:typed_data';

import '../../domain/models/note.dart';

/// Parses a pen-export CSV with the columns `x`, `y`, `t` and `stroke` into a
/// [Note].
///
/// The CSV holds positions in metres and times in seconds since the pen
/// started recording. The parser converts positions to millimetres, moves the
/// ink bounds' top-left to (0, 0), and shifts times so the first sample is at
/// 0.
///
/// Throws a [FormatException] if a column is missing, a value can't be parsed,
/// stroke indices or times go backwards, or the note has no points.
abstract final class NoteCsvParser {
  static const _metresToMillimetres = 1000.0;

  /// Parses [csv] into a [Note] with the given [id].
  static Note parse(String id, String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty || lines.first.trim().isEmpty) {
      throw const FormatException('The CSV is empty.');
    }

    final header = lines.first.trim().split(',');
    final xColumn = _columnIndex(header, 'x');
    final yColumn = _columnIndex(header, 'y');
    final tColumn = _columnIndex(header, 't');
    final strokeColumn = _columnIndex(header, 'stroke');
    final columnCount = header.length;

    // Sized for the worst case and trimmed after parsing.
    final capacity = lines.length - 1;
    final xy = Float32List(capacity * 2);
    final t = Float64List(capacity);
    final strokeStart = <int>[];
    final strokeT0 = <double>[];
    final strokeT1 = <double>[];

    var count = 0;
    var currentStroke = -1;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (var lineIndex = 1; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty) continue;

      final fields = line.split(',');
      if (fields.length != columnCount) {
        throw FormatException(
          'Expected $columnCount values but found ${fields.length}.',
          line,
          lineIndex + 1,
        );
      }

      final x =
          _parseDouble(fields[xColumn], line, lineIndex) * _metresToMillimetres;
      final y =
          _parseDouble(fields[yColumn], line, lineIndex) * _metresToMillimetres;
      final time = _parseDouble(fields[tColumn], line, lineIndex);
      final stroke =
          int.tryParse(fields[strokeColumn]) ??
          (throw FormatException('Invalid stroke index.', line, lineIndex + 1));

      if (count > 0 && time < t[count - 1]) {
        throw FormatException('Time goes backwards.', line, lineIndex + 1);
      }
      if (stroke != currentStroke) {
        if (stroke < currentStroke) {
          throw FormatException(
            'Stroke index goes backwards.',
            line,
            lineIndex + 1,
          );
        }
        currentStroke = stroke;
        strokeStart.add(count);
        strokeT0.add(time);
        strokeT1.add(time);
      } else {
        strokeT1[strokeT1.length - 1] = time;
      }

      xy[count * 2] = x;
      xy[count * 2 + 1] = y;
      t[count] = time;
      count++;

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (count == 0) {
      throw const FormatException('The CSV has no points.');
    }

    final t0 = t[0];
    for (var i = 0; i < count; i++) {
      xy[i * 2] -= minX;
      xy[i * 2 + 1] -= minY;
      t[i] -= t0;
    }
    for (var s = 0; s < strokeT0.length; s++) {
      strokeT0[s] -= t0;
      strokeT1[s] -= t0;
    }
    strokeStart.add(count);

    return Note(
      id: id,
      // `sublist` on a typed list returns a trimmed typed-list copy.
      xy: count == capacity ? xy : xy.sublist(0, count * 2),
      t: count == capacity ? t : t.sublist(0, count),
      strokeStart: Int32List.fromList(strokeStart),
      strokeT0: Float64List.fromList(strokeT0),
      strokeT1: Float64List.fromList(strokeT1),
      width: maxX - minX,
      height: maxY - minY,
    );
  }

  static int _columnIndex(List<String> header, String name) {
    final index = header.indexOf(name);
    if (index < 0) {
      throw FormatException('Missing column "$name".', header.join(','));
    }
    return index;
  }

  static double _parseDouble(String value, String line, int lineIndex) {
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Invalid number "$value".', line, lineIndex + 1);
    }
    return parsed;
  }
}
