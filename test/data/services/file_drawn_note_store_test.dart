import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/services/file_drawn_note_store.dart';

void main() {
  late Directory base;
  late FileDrawnNoteStore store;

  setUp(() {
    base = Directory.systemTemp.createTempSync('drawn_notes_test_');
    store = FileDrawnNoteStore(baseDirectory: () async => base);
  });

  tearDown(() => base.deleteSync(recursive: true));

  test('starts with no notes, creating its folder', () async {
    expect(await store.listIds(), isEmpty);
    expect(Directory('${base.path}/drawn_notes').existsSync(), isTrue);
  });

  test('writes a note as <id>.csv and reads it back', () async {
    await store.write('drawn_1', 'x,y,t,stroke\n0,0,0,0\n');

    expect(
      File('${base.path}/drawn_notes/drawn_1.csv').readAsStringSync(),
      'x,y,t,stroke\n0,0,0,0\n',
    );
    expect(await store.read('drawn_1'), 'x,y,t,stroke\n0,0,0,0\n');
  });

  test(
    'lists saved ids, and a new store finds them, as after a restart',
    () async {
      await store.write('drawn_1', 'a');
      await store.write('drawn_2', 'b');

      final restarted = FileDrawnNoteStore(baseDirectory: () async => base);

      expect(
        await restarted.listIds(),
        unorderedEquals(['drawn_1', 'drawn_2']),
      );
      expect(await restarted.read('drawn_2'), 'b');
    },
  );

  test(
    'writing again replaces the note and leaves no temporary file',
    () async {
      await store.write('drawn_1', 'first');
      await store.write('drawn_1', 'second');

      expect(await store.read('drawn_1'), 'second');
      expect(
        Directory('${base.path}/drawn_notes').listSync().map((e) => e.path),
        [endsWith('drawn_1.csv')],
      );
    },
  );

  test('ignores files that are not CSVs', () async {
    File('${base.path}/drawn_notes/notes.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('not a note');
    await store.write('drawn_1', 'a');

    expect(await store.listIds(), ['drawn_1']);
  });

  test('reading a missing note throws a FileSystemException', () async {
    await expectLater(
      store.read('drawn_9'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
