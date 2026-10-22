import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/parsers/note_csv_parser.dart';

void main() {
  group('NoteCsvParser.parse', () {
    test('converts to millimetres and moves time and bounds to zero', () {
      const csv =
          'x,y,t,stroke\n'
          '0.001,0.002,1.0,0\n'
          '0.003,0.001,1.5,0\n'
          '0.002,0.004,2.0,1\n';

      final note = NoteCsvParser.parse('n', csv);

      expect(note.id, 'n');
      expect(note.pointCount, 3);
      expect(note.xy, _closeToList([0, 1, 2, 0, 1, 3]));
      expect(note.t, [0.0, 0.5, 1.0]);
      expect(note.width, closeTo(2, 1e-9));
      expect(note.height, closeTo(3, 1e-9));
      expect(note.duration, 1.0);
    });

    test('builds the stroke table', () {
      const csv =
          'x,y,t,stroke\n'
          '0,0,0.0,0\n'
          '0,0,0.1,0\n'
          '0,0,0.5,1\n'
          '0,0,0.9,2\n'
          '0,0,1.0,2\n';

      final note = NoteCsvParser.parse('n', csv);

      expect(note.strokeCount, 3);
      expect(note.strokeStart, [0, 2, 3, 5]);
      expect(note.strokeT0, [0.0, 0.5, 0.9]);
      expect(note.strokeT1, [0.1, 0.5, 1.0]);
    });

    test('accepts scientific notation, CRLF, blank lines and any column '
        'order', () {
      const csv =
          'stroke,t,y,x\r\n'
          '0,0.977954,-8.01011e-05,-7.1898e-05\r\n'
          '\r\n'
          '0,0.980387,-0.000113614,-7.51379e-05\r\n'
          '\r\n';

      final note = NoteCsvParser.parse('n', csv);

      expect(note.pointCount, 2);
      expect(note.t[1], closeTo(0.002433, 1e-9));
      expect(note.width, closeTo(0.0032399, 1e-6));
      expect(note.height, closeTo(0.0335129, 1e-6));
    });

    group('throws FormatException when', () {
      final cases = {
        'the CSV is empty': '',
        'a column is missing': 'x,y,t\n0,0,0\n',
        'a number is invalid': 'x,y,t,stroke\n0,abc,0,0\n',
        'a stroke index is invalid': 'x,y,t,stroke\n0,0,0,a\n',
        'a row has the wrong number of values': 'x,y,t,stroke\n0,0,0\n',
        'the stroke index goes backwards': 'x,y,t,stroke\n0,0,0,1\n0,0,1,0\n',
        'time goes backwards': 'x,y,t,stroke\n0,0,1,0\n0,0,0,0\n',
        'there are no points': 'x,y,t,stroke\n',
      };
      for (final MapEntry(key: description, value: csv) in cases.entries) {
        test(description, () {
          expect(
            () => NoteCsvParser.parse('n', csv),
            throwsA(isA<FormatException>()),
          );
        });
      }
    });

    test('parses the bundled notes', () {
      // Expected values come from the analysis of the exported CSVs.
      final expected = {
        'note_1': (points: 1478, strokes: 13, width: 40.4, height: 7.1),
        'note_2': (points: 3788, strokes: 24, width: 95.5, height: 13.8),
        'note_3': (points: 1528, strokes: 8, width: 25.0, height: 33.7),
        'note_4': (points: 2011, strokes: 13, width: 62.6, height: 6.2),
        'note_5': (points: 2487, strokes: 14, width: 75.4, height: 14.4),
      };
      for (final MapEntry(key: id, value: e) in expected.entries) {
        final csv = File('assets/notes/$id.csv').readAsStringSync();

        final note = NoteCsvParser.parse(id, csv);

        expect(note.pointCount, e.points, reason: id);
        expect(note.strokeCount, e.strokes, reason: id);
        expect(note.width, closeTo(e.width, 0.06), reason: id);
        expect(note.height, closeTo(e.height, 0.06), reason: id);
        expect(note.t.first, 0, reason: id);
        expect(note.strokeStart.last, note.pointCount, reason: id);
      }
    });
  });
}

Matcher _closeToList(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (e, actual) => (actual - e).abs() < 1e-5,
  'is within 1e-5 of',
);
