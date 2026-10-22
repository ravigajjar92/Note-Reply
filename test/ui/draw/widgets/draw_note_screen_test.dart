import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/canvas_settings_repository.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/data/services/drawn_note_store.dart';
import 'package:note_replay_animation/domain/models/note_summary.dart';
import 'package:note_replay_animation/ui/draw/widgets/draw_note_screen.dart';
import 'package:note_replay_animation/utils/result.dart';

import '../../../helpers/fake_note_asset_service.dart';

void main() {
  late NoteRepository repository;
  late CanvasSettingsRepository settings;
  late List<NoteSummary> replayed;

  setUp(() {
    repository = NoteRepository(assetService: FakeNoteAssetService());
    settings = CanvasSettingsRepository();
    replayed = [];
  });

  tearDown(() => settings.dispose());

  /// Home with a button that opens the New note screen, so Back has
  /// somewhere to go.
  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DrawNoteScreen(
                    noteRepository: repository,
                    settingsRepository: settings,
                    replayBuilder: (note) {
                      replayed.add(note);
                      return Scaffold(
                        appBar: AppBar(title: Text('Replay ${note.title}')),
                      );
                    },
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// Draws one stroke across the middle of the canvas, with timestamps.
  Future<void> drawStroke(WidgetTester tester, {double y = 300}) async {
    final gesture = await tester.createGesture();
    await gesture.down(Offset(200, y), timeStamp: Duration.zero);
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(
        Offset(200 + i * 20, y),
        timeStamp: Duration(milliseconds: i * 8),
      );
    }
    await gesture.up(timeStamp: const Duration(milliseconds: 48));
    await tester.pump();
  }

  IconButton iconButton(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  testWidgets('opens on an empty canvas with a hint, and no Animate button', (
    tester,
  ) async {
    await openScreen(tester);

    expect(find.widgetWithText(AppBar, 'New note'), findsOneWidget);
    expect(find.text('Write anything'), findsOneWidget);
    expect(find.text('Animate'), findsNothing);
    expect(iconButton(tester, Icons.undo).onPressed, isNull);
    expect(iconButton(tester, Icons.delete_outline).onPressed, isNull);
  });

  testWidgets('writing hides the hint and shows Animate, Undo and Clear', (
    tester,
  ) async {
    await openScreen(tester);

    await drawStroke(tester);

    expect(find.text('Write anything'), findsNothing);
    expect(find.text('Animate'), findsOneWidget);
    expect(iconButton(tester, Icons.undo).onPressed, isNotNull);
    expect(iconButton(tester, Icons.delete_outline).onPressed, isNotNull);
  });

  testWidgets('undo of the only stroke brings the hint back', (tester) async {
    await openScreen(tester);
    await drawStroke(tester);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();

    expect(find.text('Write anything'), findsOneWidget);
    expect(find.text('Animate'), findsNothing);
  });

  testWidgets('Animate adds the note and replaces this screen with its '
      'replay', (tester) async {
    await openScreen(tester);
    await drawStroke(tester);
    await drawStroke(tester, y: 360);

    await tester.tap(find.text('Animate'));
    await tester.pumpAndSettle();

    expect(replayed, const [NoteSummary(id: 'drawn_1', title: 'New note 1')]);
    expect(find.text('Replay New note 1'), findsOneWidget);
    expect(find.byType(DrawNoteScreen), findsNothing);
    final notes = await repository.listNotes();
    expect(
      (notes as Ok<List<NoteSummary>>).value.map((n) => n.title),
      contains('New note 1'),
    );

    // Back from the replay goes to Home, not back to the canvas.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('when saving fails, stays on the canvas and says so', (
    tester,
  ) async {
    repository = NoteRepository(
      assetService: FakeNoteAssetService(),
      drawnNoteStore: _FailingStore(),
    );
    await openScreen(tester);
    await drawStroke(tester);

    await tester.tap(find.text('Animate'));
    await tester.pump();

    expect(find.text("Couldn't save the note. Try again."), findsOneWidget);
    expect(find.byType(DrawNoteScreen), findsOneWidget);
    expect(replayed, isEmpty);
    expect(find.text('Write anything'), findsNothing);
  });

  testWidgets('Back with nothing written leaves at once', (tester) async {
    await openScreen(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Back with ink asks first; Keep writing stays, Discard leaves', (
    tester,
  ) async {
    await openScreen(tester);
    await drawStroke(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this note?'), findsOneWidget);

    await tester.tap(find.text('Keep writing'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawNoteScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(replayed, isEmpty);
  });
}

/// A store whose writes always fail, like a full disk.
class _FailingStore extends InMemoryDrawnNoteStore {
  @override
  Future<void> write(String id, String csv) async =>
      throw const FileSystemException('No space left on device');
}
