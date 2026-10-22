import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/domain/models/ink_recording.dart';
import 'package:note_replay_animation/ui/note_list/view_models/note_list_view_model.dart';
import 'package:note_replay_animation/ui/note_list/widgets/note_list_screen.dart';
import 'package:note_replay_animation/domain/models/note_summary.dart';

import '../../../helpers/fake_note_asset_service.dart';

void main() {
  late FakeNoteAssetService service;
  late NoteRepository repository;
  late NoteListViewModel viewModel;
  late List<NoteSummary> openedNotes;

  setUp(() {
    service = FakeNoteAssetService(assets: noteAssets(5));
    repository = NoteRepository(assetService: service);
    viewModel = NoteListViewModel(repository: repository);
    openedNotes = [];
  });

  tearDown(() => viewModel.dispose());

  // Stand-in detail and New note screens, so these tests stay about Home.
  Widget screen() => MaterialApp(
    home: NoteListScreen(
      viewModel: viewModel,
      noteDetailBuilder: (note) {
        openedNotes.add(note);
        return Scaffold(appBar: AppBar(title: Text('Detail ${note.id}')));
      },
      newNoteBuilder: () =>
          Scaffold(appBar: AppBar(title: const Text('Writing a note'))),
    ),
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
  }

  SearchBar searchBar(WidgetTester tester) =>
      tester.widget<SearchBar>(find.byType(SearchBar));

  Finder clearButton() => find.byTooltip('Clear search');

  testWidgets('shows the title, the search bar and only the note titles', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.widgetWithText(AppBar, 'Notes'), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);
    expect(searchBar(tester).enabled, isTrue);
    expect(find.byType(ListTile), findsNWidgets(5));
    for (var i = 1; i <= 5; i++) {
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Note $i'),
      );
      expect(tile.subtitle, isNull);
      expect(tile.leading, isNull);
      expect(tile.trailing, isNull);
    }
  });

  group('New note button', () {
    testWidgets('opens the New note screen', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('New note'));
      await tester.pumpAndSettle();

      expect(find.text('Writing a note'), findsOneWidget);
    });

    testWidgets('a note added there is listed on return, without a spinner', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('New note'));
      await tester.pumpAndSettle();

      await repository.addDrawnNote(
        InkRecording()
          ..beginStroke(0, 0, 0)
          ..addPoint(1, 1, 0.1)
          ..endStroke(),
      );
      await tester.pageBack();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(6));
      expect(find.text('New note 1'), findsOneWidget);
    });

    testWidgets('is shown in every state, including errors', (tester) async {
      service.listError = Exception('manifest unreadable');

      await pumpScreen(tester);

      expect(find.byTooltip('New note'), findsOneWidget);
    });
  });

  testWidgets('tapping a note opens its detail screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Note 3'));
    await tester.pumpAndSettle();

    expect(openedNotes, const [
      NoteSummary(
        id: 'note_3',
        title: 'Note 3',
        assetPath: 'assets/notes/note_3.csv',
      ),
    ]);
    expect(find.text('Detail note_3'), findsOneWidget);
  });

  testWidgets('shows a spinner and a disabled search bar while loading', (
    tester,
  ) async {
    service.listGate = Completer<void>();

    await tester.pumpWidget(screen());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(searchBar(tester).enabled, isFalse);

    service.listGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(5));
  });

  testWidgets('shows the empty state with a disabled search bar', (
    tester,
  ) async {
    service.assets = [];

    await pumpScreen(tester);

    expect(find.text('No notes yet'), findsOneWidget);
    expect(searchBar(tester).enabled, isFalse);
  });

  testWidgets('shows the error state, and Retry loads the notes', (
    tester,
  ) async {
    service.listError = Exception('manifest unreadable');

    await pumpScreen(tester);

    expect(find.text("Couldn't load notes."), findsOneWidget);
    expect(searchBar(tester).enabled, isFalse);

    service.listError = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(service.listCalls, 2);
    expect(find.byType(ListTile), findsNWidgets(5));
  });

  group('search', () {
    testWidgets('filters the list as you type', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(SearchBar), '3');
      await tester.pump();

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Note 3'), findsOneWidget);
    });

    testWidgets('shows the clear button only when there is text', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(clearButton(), findsNothing);

      await tester.enterText(find.byType(SearchBar), '3');
      await tester.pump();
      expect(clearButton(), findsOneWidget);

      await tester.tap(clearButton());
      await tester.pump();
      expect(clearButton(), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.widgetWithText(SearchBar, '3'), findsNothing);
    });

    testWidgets('shows a message when nothing matches, with Clear search', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(SearchBar), ' xyz ');
      await tester.pump();

      expect(find.text('No notes match "xyz"'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(5));
      expect(viewModel.query, isEmpty);
    });

    testWidgets('announces the number of matching notes', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(SearchBar), '3');
      await tester.pump();
      await tester.enterText(find.byType(SearchBar), 'xyz');
      await tester.pump();

      expect(tester.takeAnnouncements(), [
        isAccessibilityAnnouncement('1 note'),
        isAccessibilityAnnouncement('No matching notes'),
      ]);
    });

    testWidgets('is kept after opening a note and going back', (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(SearchBar), '3');
      await tester.pump();

      await tester.tap(find.text('Note 3'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SearchBar, '3'), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    });
  });
}
