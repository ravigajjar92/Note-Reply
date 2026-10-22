import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/domain/models/ink_recording.dart';

void main() {
  late InkRecording recording;

  setUp(() => recording = InkRecording());

  /// Writes a stroke through [points], each `(x, y, time)`.
  void stroke(List<(double, double, double)> points) {
    final (x, y, t) = points.first;
    recording.beginStroke(x, y, t);
    for (final (x, y, t) in points.skip(1)) {
      recording.addPoint(x, y, t);
    }
    recording.endStroke();
  }

  test('starts empty', () {
    expect(recording.isEmpty, isTrue);
    expect(recording.strokeCount, 0);
    expect(recording.activePoints, isEmpty);
  });

  test('a stroke in progress is visible before it ends', () {
    recording
      ..beginStroke(1, 2, 10)
      ..addPoint(3, 4, 10.1);

    expect(recording.isEmpty, isFalse);
    expect(recording.strokeCount, 0);
    expect(recording.activePoints, [1, 2, 3, 4]);
  });

  test('ending a stroke moves it to the finished strokes', () {
    stroke([(1, 2, 10), (3, 4, 10.1)]);

    expect(recording.strokeCount, 1);
    expect(recording.strokePoints(0), [1, 2, 3, 4]);
    expect(recording.activePoints, isEmpty);
  });

  test('records long strokes past the initial buffer size', () {
    stroke([for (var i = 0; i < 1000; i++) (i.toDouble(), 0, i / 100)]);

    expect(recording.strokePoints(0).length, 2000);
    expect(recording.strokePoints(0)[1998], 999);
  });

  test('undo removes the stroke in progress, then finished strokes', () {
    stroke([(0, 0, 0), (1, 1, 0.1)]);
    stroke([(2, 2, 0.5), (3, 3, 0.6)]);
    recording.beginStroke(5, 5, 1);

    recording.undo();
    expect(recording.activePoints, isEmpty);
    expect(recording.strokeCount, 2);

    recording.undo();
    expect(recording.strokeCount, 1);
  });

  test('clear removes everything', () {
    stroke([(0, 0, 0), (1, 1, 0.1)]);
    recording
      ..beginStroke(5, 5, 1)
      ..clear();

    expect(recording.isEmpty, isTrue);
  });

  group('toNote', () {
    test('moves the ink to (0, 0) and time to 0, and builds the stroke '
        'table', () {
      stroke([(10, 20, 100), (12, 21, 100.1)]);
      stroke([(11, 25, 100.5), (11, 26, 100.6), (11, 27, 100.7)]);

      final note = recording.toNote('n');

      expect(note.id, 'n');
      expect(note.pointCount, 5);
      expect(note.strokeCount, 2);
      expect(note.xy, [0, 0, 2, 1, 1, 5, 1, 6, 1, 7]);
      expect(note.t[0], 0);
      expect(note.t[4], closeTo(0.7, 1e-9));
      expect(note.strokeStart, [0, 2, 5]);
      expect(note.strokeT0[1], closeTo(0.5, 1e-9));
      expect(note.strokeT1[0], closeTo(0.1, 1e-9));
      expect(note.width, 2);
      expect(note.height, 7);
    });

    test('keeps time from going backwards', () {
      stroke([(0, 0, 5), (1, 0, 4), (2, 0, 6)]);

      final note = recording.toNote('n');

      expect(note.t, [0, 0, 1]);
    });

    test('a single tap becomes a one-point stroke', () {
      stroke([(4, 4, 1)]);

      final note = recording.toNote('n');

      expect(note.pointCount, 1);
      expect(note.duration, 0);
      expect(note.width, 0);
    });

    test('leaves out a stroke still in progress', () {
      stroke([(0, 0, 0), (1, 0, 0.1)]);
      recording.beginStroke(9, 9, 1);

      expect(recording.toNote('n').strokeCount, 1);
    });

    test('throws when nothing has been written', () {
      expect(() => recording.toNote('n'), throwsStateError);
    });
  });
}
