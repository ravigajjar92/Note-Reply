import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/parsers/note_csv_parser.dart';
import 'package:note_replay_animation/domain/models/note.dart';
import 'package:note_replay_animation/ui/replay/view_models/replay_cursor.dart';
import 'package:note_replay_animation/ui/replay/view_models/replay_frame.dart';

import '../../../helpers/fake_note_repository.dart';

/// What the cursor should report at [time], found by scanning everything.
({int committed, int active, int visibleEnd}) bruteForce(
  Note note,
  double time,
) {
  var committed = 0;
  while (committed < note.strokeCount && note.strokeT1[committed] <= time) {
    committed++;
  }
  if (committed == note.strokeCount || note.strokeT0[committed] > time) {
    return (committed: committed, active: -1, visibleEnd: 0);
  }
  var end = note.strokeStart[committed];
  while (end < note.strokeStart[committed + 1] && note.t[end] <= time) {
    end++;
  }
  return (committed: committed, active: committed, visibleEnd: end);
}

void main() {
  late ReplayFrame frame;

  setUp(() => frame = ReplayFrame());
  tearDown(() => frame.dispose());

  void expectMatchesBruteForce(Note note, double time) {
    final expected = bruteForce(note, time);
    expect(frame.committedCount, expected.committed, reason: 't=$time');
    expect(frame.activeStroke, expected.active, reason: 't=$time');
    if (expected.active >= 0) {
      expect(frame.visibleEnd, expected.visibleEnd, reason: 't=$time');
    }
  }

  group('with the two-stroke note', () {
    late Note note;
    late ReplayCursor cursor;

    setUp(() {
      note = NoteCsvParser.parse('n', twoStrokeCsv);
      cursor = ReplayCursor(note);
    });

    test('at 0 shows the first sample of stroke 0 as a dot', () {
      cursor.moveTo(0, frame);

      expect(frame.committedCount, 0);
      expect(frame.activeStroke, 0);
      expect(frame.visibleEnd, 1);
      expect(frame.hasHead, isFalse);
      expect(frame.penDown, isTrue);
    });

    test('between samples, places the pen exactly between them', () {
      cursor.moveTo(0.15, frame);

      expect(frame.visibleEnd, 2);
      expect(frame.hasHead, isTrue);
      expect(frame.penPoint[0], closeTo(1.5, 1e-5));
      expect(frame.penPoint[1], closeTo(0, 1e-5));
      expect(frame.headSegment, [
        closeTo(1, 1e-5),
        closeTo(0, 1e-5),
        closeTo(1.5, 1e-5),
        closeTo(0, 1e-5),
      ]);
    });

    test('at the last sample of a stroke, the stroke is finished', () {
      cursor.moveTo(note.strokeT1[0], frame);

      expect(frame.committedCount, 1);
      expect(frame.activeStroke, -1);
      expect(frame.penDown, isFalse);
    });

    test('between strokes, the pen is up', () {
      cursor.moveTo(0.4, frame);

      expect(frame.committedCount, 1);
      expect(frame.activeStroke, -1);
      expect(frame.hasHead, isFalse);
    });

    test('pen down: the writing interval is the gap to the next sample', () {
      cursor.moveTo(0.15, frame);

      expect(frame.writingInterval, closeTo(0.1, 1e-9));
      expect(frame.liftInterval, -1);
    });

    test('pen up between strokes: the lift interval is the gap between '
        'them', () {
      cursor.moveTo(0.4, frame);

      // Stroke 0 ends at 0.3 s and stroke 1 starts at 0.5 s.
      expect(frame.liftInterval, closeTo(0.2, 1e-9));
      expect(frame.writingInterval, -1);
    });

    test('after the last stroke, neither interval applies', () {
      cursor.moveTo(note.duration, frame);

      expect(frame.writingInterval, -1);
      expect(frame.liftInterval, -1);
    });

    test('at the end, every stroke is finished', () {
      cursor.moveTo(note.duration, frame);

      expect(frame.committedCount, note.strokeCount);
      expect(frame.activeStroke, -1);
    });

    test('moving backwards gives the same result as moving forwards', () {
      cursor
        ..moveTo(0.7, frame)
        ..moveTo(0.15, frame);

      expect(frame.committedCount, 0);
      expect(frame.activeStroke, 0);
      expect(frame.visibleEnd, 2);
      expect(frame.penPoint[0], closeTo(1.5, 1e-5));
    });
  });

  group('with a bundled note', () {
    late Note note;

    setUp(() => note = NoteCsvParser.parse('note_1', note1Csv()));

    test('playing forward at 120 fps matches a full scan every frame', () {
      final cursor = ReplayCursor(note);
      for (var time = 0.0; time <= note.duration; time += 1 / 120) {
        cursor.moveTo(time, frame);
        expectMatchesBruteForce(note, time);
      }
    });

    test('random seeks forwards and backwards match a full scan', () {
      final cursor = ReplayCursor(note);
      final random = Random(42);
      for (var i = 0; i < 500; i++) {
        final time = random.nextDouble() * note.duration;
        cursor.moveTo(time, frame);
        expectMatchesBruteForce(note, time);
      }
    });
  });
}
