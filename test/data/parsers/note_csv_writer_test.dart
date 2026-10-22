import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/parsers/note_csv_parser.dart';
import 'package:note_replay_animation/data/parsers/note_csv_writer.dart';
import 'package:note_replay_animation/domain/models/ink_recording.dart';
import 'package:note_replay_animation/domain/models/note.dart';

import '../../helpers/fake_note_repository.dart';

void main() {
  void expectSameNote(Note actual, Note expected) {
    expect(actual.pointCount, expected.pointCount);
    expect(actual.strokeStart, expected.strokeStart);
    for (var i = 0; i < expected.xy.length; i++) {
      expect(actual.xy[i], closeTo(expected.xy[i], 1e-4), reason: 'xy[$i]');
    }
    for (var i = 0; i < expected.t.length; i++) {
      expect(actual.t[i], closeTo(expected.t[i], 1e-12), reason: 't[$i]');
    }
    expect(actual.width, closeTo(expected.width, 1e-4));
    expect(actual.height, closeTo(expected.height, 1e-4));
  }

  test('writes the header and one row per point, in metres', () {
    final note =
        (InkRecording()
              ..beginStroke(0, 0, 1)
              ..addPoint(2, 3, 1.25)
              ..endStroke()
              ..beginStroke(4, 1, 2)
              ..endStroke())
            .toNote('n');

    expect(
      NoteCsvWriter.write(note),
      'x,y,t,stroke\n'
      '0.0,0.0,0.0,0\n'
      '0.002,0.003,0.25,0\n'
      '0.004,0.001,1.0,1\n',
    );
  });

  test('parsing what was written gives back the same note', () {
    final original = NoteCsvParser.parse('note_1', note1Csv());

    final roundTripped = NoteCsvParser.parse(
      'note_1',
      NoteCsvWriter.write(original),
    );

    expectSameNote(roundTripped, original);
  });

  test('keeps full time precision, unlike the pen export', () {
    final note =
        (InkRecording()
              ..beginStroke(0, 0, 12345.678901234)
              ..addPoint(1, 0, 12345.681334)
              ..endStroke())
            .toNote('n');

    final parsed = NoteCsvParser.parse('n', NoteCsvWriter.write(note));

    expect(parsed.t[1], note.t[1]);
  });
}
