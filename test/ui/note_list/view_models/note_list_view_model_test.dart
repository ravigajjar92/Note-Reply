import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/domain/models/ink_recording.dart';
import 'package:note_replay_animation/ui/note_list/view_models/note_list_view_model.dart';

import '../../../helpers/fake_note_asset_service.dart';

void main() {
  late FakeNoteAssetService service;
  late NoteListViewModel viewModel;
  late int notifications;

  setUp(() {
    service = FakeNoteAssetService(assets: noteAssets(5));
    viewModel = NoteListViewModel(
      repository: NoteRepository(assetService: service),
    );
    notifications = 0;
    viewModel.addListener(() => notifications++);
  });

  tearDown(() => viewModel.dispose());

  List<String> visibleTitles() => [
    for (final note in viewModel.visibleNotes) note.title,
  ];

  group('load', () {
    test('starts in the loading state', () {
      expect(viewModel.state, isA<NoteListLoading>());
      expect(viewModel.visibleNotes, isEmpty);
    });

    test('shows loading, then the notes', () async {
      service.listGate = Completer<void>();

      final loading = viewModel.load();
      expect(viewModel.state, isA<NoteListLoading>());
      service.listGate!.complete();
      await loading;

      expect(viewModel.state, isA<NoteListData>());
      expect(visibleTitles(), [
        'Note 1',
        'Note 2',
        'Note 3',
        'Note 4',
        'Note 5',
      ]);
      expect(notifications, 2);
    });

    test('shows the empty state when there are no notes', () async {
      service.assets = [];

      await viewModel.load();

      expect(viewModel.state, isA<NoteListEmpty>());
      expect(viewModel.visibleNotes, isEmpty);
    });

    test('shows the error state, and Retry loads the notes', () async {
      service.listError = Exception('manifest unreadable');

      await viewModel.load();
      expect(viewModel.state, isA<NoteListError>());

      service.listError = null;
      await viewModel.load();
      expect(viewModel.state, isA<NoteListData>());
      expect(viewModel.visibleNotes, hasLength(5));
    });

    test('refresh shows a newly added note without showing loading',
        () async {
      final repository = NoteRepository(assetService: service);
      final viewModel = NoteListViewModel(repository: repository);
      await viewModel.load();
      final states = <NoteListState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      await repository.addDrawnNote(
        InkRecording()
          ..beginStroke(0, 0, 0)
          ..endStroke(),
      );
      await viewModel.refresh();

      expect(states, [isA<NoteListData>()]);
      expect(viewModel.visibleNotes, hasLength(6));
      expect(viewModel.visibleNotes.last.title, 'New note 1');
      viewModel.dispose();
    });

    test('does not notify after dispose', () async {
      final viewModel = NoteListViewModel(
        repository: NoteRepository(assetService: service),
      );
      service.listGate = Completer<void>();

      final loading = viewModel.load();
      viewModel.dispose();
      service.listGate!.complete();

      await expectLater(loading, completes);
    });
  });

  group('search', () {
    setUp(() => viewModel.load());

    test('ignores case', () {
      viewModel.search('NOTE 3');

      expect(visibleTitles(), ['Note 3']);
    });

    test('trims leading and trailing spaces', () {
      viewModel.search('  3 ');

      expect(visibleTitles(), ['Note 3']);
      expect(viewModel.query, '  3 ');
    });

    test('matches anywhere in the title', () {
      viewModel.search('note');

      expect(viewModel.visibleNotes, hasLength(5));
    });

    test('returns nothing when no title matches', () {
      viewModel.search('xyz');

      expect(viewModel.visibleNotes, isEmpty);
      expect(viewModel.state, isA<NoteListData>());
    });

    test('clearSearch shows every note again', () {
      viewModel
        ..search('3')
        ..clearSearch();

      expect(viewModel.visibleNotes, hasLength(5));
      expect(viewModel.query, isEmpty);
    });

    test('notifies once per change, and not for the same text', () {
      notifications = 0;

      viewModel
        ..search('3')
        ..search('3');

      expect(notifications, 1);
    });

    test('is kept when the list reloads', () async {
      viewModel.search('3');

      await viewModel.load();

      expect(visibleTitles(), ['Note 3']);
    });
  });
}
