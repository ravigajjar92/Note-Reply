import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/data/services/drawn_note_store.dart';
import 'package:note_replay_animation/domain/models/ink_recording.dart';
import 'package:note_replay_animation/domain/models/note.dart';
import 'package:note_replay_animation/domain/models/note_summary.dart';
import 'package:note_replay_animation/utils/result.dart';

import '../../helpers/fake_note_asset_service.dart';

void main() {
  late FakeNoteAssetService service;
  late NoteRepository repository;

  setUp(() {
    service = FakeNoteAssetService();
    repository = NoteRepository(assetService: service);
  });

  group('listNotes', () {
    test('builds titles from file names, in natural order, skipping other '
        'assets', () async {
      service.assets = [
        'assets/notes/note_10.csv',
        'assets/notes/note_2.csv',
        'assets/notes/note_1.csv',
        'assets/notes/my_note.csv',
        'assets/notes/readme.md',
        'assets/other/note_3.csv',
        'fonts/Roboto.ttf',
      ];

      final result = await repository.listNotes();

      expect(result, isA<Ok<List<NoteSummary>>>());
      expect((result as Ok<List<NoteSummary>>).value, const [
        NoteSummary(
          id: 'my_note',
          title: 'My note',
          assetPath: 'assets/notes/my_note.csv',
        ),
        NoteSummary(
          id: 'note_1',
          title: 'Note 1',
          assetPath: 'assets/notes/note_1.csv',
        ),
        NoteSummary(
          id: 'note_2',
          title: 'Note 2',
          assetPath: 'assets/notes/note_2.csv',
        ),
        NoteSummary(
          id: 'note_10',
          title: 'Note 10',
          assetPath: 'assets/notes/note_10.csv',
        ),
      ]);
    });

    test('serves the second call from the cache', () async {
      service.assets = noteAssets(5);

      await repository.listNotes();
      await repository.listNotes();

      expect(service.listCalls, 1);
    });

    test(
      'returns an error when the service fails, and retries next time',
      () async {
        service.listError = Exception('manifest unreadable');

        final failed = await repository.listNotes();
        service
          ..listError = null
          ..assets = noteAssets(1);
        final retried = await repository.listNotes();

        expect(failed, isA<Error<List<NoteSummary>>>());
        expect(retried, isA<Ok<List<NoteSummary>>>());
        expect(service.listCalls, 2);
      },
    );
  });

  group('addDrawnNote', () {
    InkRecording oneStroke() => InkRecording()
      ..beginStroke(10, 10, 5)
      ..addPoint(12, 11, 5.1)
      ..endStroke();

    late InMemoryDrawnNoteStore store;

    setUp(() {
      service.assets = noteAssets(2);
      store = InMemoryDrawnNoteStore();
      repository = NoteRepository(assetService: service, drawnNoteStore: store);
    });

    List<String> titles(Result<List<NoteSummary>> result) => [
      for (final n in (result as Ok<List<NoteSummary>>).value) n.title,
    ];

    test('lists drawn notes after the bundled ones, numbered in order',
        () async {
      final first = await repository.addDrawnNote(oneStroke());
      final second = await repository.addDrawnNote(oneStroke());

      expect(
        (first as Ok<NoteSummary>).value,
        const NoteSummary(id: 'drawn_1', title: 'New note 1'),
      );
      expect((second as Ok<NoteSummary>).value.title, 'New note 2');
      expect(titles(await repository.listNotes()), [
        'Note 1',
        'Note 2',
        'New note 1',
        'New note 2',
      ]);
    });

    test('saves the note to the store', () async {
      await repository.addDrawnNote(oneStroke());

      expect(await store.listIds(), ['drawn_1']);
      expect(await store.read('drawn_1'), startsWith('x,y,t,stroke\n'));
    });

    test('a new repository on the same store lists and loads saved notes, '
        'as after a restart', () async {
      await repository.addDrawnNote(oneStroke());
      await repository.addDrawnNote(oneStroke());

      final restarted = NoteRepository(
        assetService: service,
        drawnNoteStore: store,
      );

      expect(titles(await restarted.listNotes()), [
        'Note 1',
        'Note 2',
        'New note 1',
        'New note 2',
      ]);
      final result = await restarted.loadNote('drawn_2');
      final note = (result as Ok<Note>).value;
      expect(note.pointCount, 2);
      expect(note.t.last, closeTo(0.1, 1e-9));
      expect(note.xy[2], closeTo(2, 1e-4));
      expect(service.loadCalls, 0);
    });

    test('numbering continues from the highest saved number', () async {
      await store.write('drawn_7', 'x,y,t,stroke\n0,0,0,0\n');

      final added = await repository.addDrawnNote(oneStroke());

      expect((added as Ok<NoteSummary>).value.title, 'New note 8');
    });

    test('ignores files in the store that are not drawn notes', () async {
      await store.write('notes_backup', 'x,y,t,stroke\n0,0,0,0\n');

      expect(titles(await repository.listNotes()), ['Note 1', 'Note 2']);
    });

    test('when saving fails, returns the error and adds nothing', () async {
      repository = NoteRepository(
        assetService: service,
        drawnNoteStore: _FailingStore(),
      );

      final result = await repository.addDrawnNote(oneStroke());

      expect(result, isA<Error<NoteSummary>>());
      expect(titles(await repository.listNotes()), ['Note 1', 'Note 2']);
    });
  });

  group('loadNote', () {
    const csv = 'x,y,t,stroke\n0,0,1.0,0\n0.001,0,1.5,0\n';

    setUp(() {
      service
        ..assets = noteAssets(2)
        ..csvByPath = {'assets/notes/note_2.csv': csv};
    });

    test('parses the note and caches it', () async {
      final first = await repository.loadNote('note_2');
      final second = await repository.loadNote('note_2');

      expect(first, isA<Ok<Note>>());
      final note = (first as Ok<Note>).value;
      expect(note.id, 'note_2');
      expect(note.pointCount, 2);
      expect((second as Ok<Note>).value, same(note));
      expect(service.loadCalls, 1);
    });

    test('returns NoteNotFoundException for an unknown id', () async {
      final result = await repository.loadNote('note_9');

      expect(
        result,
        isA<Error<Note>>().having(
          (e) => e.error,
          'error',
          isA<NoteNotFoundException>(),
        ),
      );
    });

    test('returns FormatException for an invalid CSV', () async {
      service.csvByPath = {'assets/notes/note_1.csv': 'x,y\n'};

      final result = await repository.loadNote('note_1');

      expect(
        result,
        isA<Error<Note>>().having(
          (e) => e.error,
          'error',
          isA<FormatException>(),
        ),
      );
    });
  });
}

/// A store whose writes always fail, like a full disk.
class _FailingStore extends InMemoryDrawnNoteStore {
  @override
  Future<void> write(String id, String csv) async =>
      throw const FileSystemException('No space left on device');
}
