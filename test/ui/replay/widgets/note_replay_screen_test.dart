import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/parsers/note_csv_parser.dart';
import 'package:note_replay_animation/data/repositories/canvas_settings_repository.dart';
import 'package:note_replay_animation/ui/replay/widgets/note_replay_screen.dart';
import 'package:note_replay_animation/ui/replay/widgets/note_stats_panel.dart';
import 'package:note_replay_animation/ui/replay/widgets/replay_canvas.dart';
import 'package:note_replay_animation/ui/replay/widgets/replay_progress_bar.dart';

import '../../../helpers/fake_note_repository.dart';

void main() {
  late FakeNoteRepository repository;
  late CanvasSettingsRepository settings;

  setUp(() {
    // note_1 is about 6 s long: long enough for 100 frames of playback.
    repository = FakeNoteRepository(csv: note1Csv());
    settings = CanvasSettingsRepository();
  });

  tearDown(() => settings.dispose());

  Widget screen() => MaterialApp(
    home: NoteReplayScreen(
      note: testSummary,
      noteRepository: repository,
      settingsRepository: settings,
    ),
  );

  Future<void> pumpLoaded(WidgetTester tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title while loading, without the floating button '
      'or progress bar', (tester) async {
    repository.loadGate = Completer<void>();

    await tester.pumpWidget(screen());

    expect(find.widgetWithText(AppBar, 'Note 1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(ReplayProgressBar), findsNothing);

    repository.loadGate!.complete();
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(ReplayProgressBar), findsOneWidget);
  });

  testWidgets('with autoPlay, starts playing as soon as it loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteReplayScreen(
          note: testSummary,
          noteRepository: repository,
          settingsRepository: settings,
          autoPlay: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('0:00 / 0:06'), findsOneWidget);
  });

  testWidgets('opens on the complete note, ready to play', (tester) async {
    await pumpLoaded(tester);

    expect(find.byType(ReplayCanvas), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.text('0:06 / 0:06'), findsOneWidget);
  });

  testWidgets('the floating button goes Play → Pause → Resume → Replay', (
    tester,
  ) async {
    await pumpLoaded(tester);

    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('0:00 / 0:06'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Resume'), findsOneWidget);
    expect(find.text('0:01 / 0:06'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.byTooltip('Replay'), findsOneWidget);
    expect(find.text('0:06 / 0:06'), findsOneWidget);
  });

  testWidgets('shows the error and Retry loads the note', (tester) async {
    repository.loadError = Exception('unreadable');

    await pumpLoaded(tester);

    expect(find.text("Couldn't open this note."), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    repository.loadError = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.byType(ReplayCanvas), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('shows the note stats at the bottom of the canvas', (
    tester,
  ) async {
    await pumpLoaded(tester);
    final canvas = tester.getSize(find.byType(ReplayCanvas));

    expect(find.text('Points 1,478'), findsOneWidget);
    expect(find.text('Strokes 13'), findsOneWidget);
    expect(
      find.text('Canvas ${canvas.width.round()} × ${canvas.height.round()} px'),
      findsOneWidget,
    );
    // The complete note has no current point.
    expect(find.text('Pen writing —'), findsOneWidget);
    expect(find.text('Pen lift —'), findsOneWidget);
  });

  testWidgets('pen writing and pen lift show the ms to the next point', (
    tester,
  ) async {
    final note = NoteCsvParser.parse('note_1', note1Csv());
    final firstGapMicros = ((note.strokeT0[1] - note.strokeT1[0]) * 1e6)
        .round();
    await pumpLoaded(tester);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    // Pen down in the first stroke: samples are about 2.43 ms apart.
    await tester.pump(const Duration(milliseconds: 100));
    var i = 0;
    while (note.t[i + 1] <= 0.1) {
      i++;
    }
    final sampleMicros = ((note.t[i + 1] - note.t[i]) * 1e6).round();
    expect(sampleMicros, inInclusiveRange(2400, 2500));
    expect(
      find.text('Pen writing ${formatMillis(sampleMicros)}'),
      findsOneWidget,
    );
    expect(find.text('Pen lift —'), findsOneWidget);

    // Pen up after the first stroke: the gap to the second stroke.
    final gapMiddle = (note.strokeT1[0] + note.strokeT0[1]) / 2;
    await tester.pump(
      Duration(microseconds: ((gapMiddle - 0.1) * 1e6).round()),
    );
    expect(find.text('Pen writing —'), findsOneWidget);
    expect(
      find.text('Pen lift ${formatMillis(firstGapMicros)}'),
      findsOneWidget,
    );
  });

  testWidgets('the Settings button opens the settings sheet', (tester) async {
    await pumpLoaded(tester);

    await tester.tap(find.byTooltip('Canvas & Pen Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas & Pen Settings'), findsOneWidget);
  });

  testWidgets('playback rebuilds nothing: 100 frames reuse the same app bar, '
      'button, canvas and progress bar', (tester) async {
    await pumpLoaded(tester);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    Widget widgetOf(Type type) => tester.widget(find.byType(type));
    final before = [
      for (final type in [
        AppBar,
        FloatingActionButton,
        ReplayCanvas,
        ReplayProgressBar,
      ])
        widgetOf(type),
    ];

    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Playback moved on, so frames were drawn...
    expect(find.text('0:01 / 0:06'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    // ...but none of these widgets was rebuilt.
    final after = [
      for (final type in [
        AppBar,
        FloatingActionButton,
        ReplayCanvas,
        ReplayProgressBar,
      ])
        widgetOf(type),
    ];
    for (var i = 0; i < before.length; i++) {
      expect(identical(before[i], after[i]), isTrue, reason: '${before[i]}');
    }
  });

  testWidgets('leaving without playing disposes cleanly', (tester) async {
    await pumpLoaded(tester);

    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving while playing stops the ticker cleanly', (tester) async {
    await pumpLoaded(tester);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
  });
}
