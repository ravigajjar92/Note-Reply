import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/canvas_settings_repository.dart';
import 'package:note_replay_animation/domain/models/canvas_settings.dart';
import 'package:note_replay_animation/ui/replay/widgets/canvas_settings_sheet.dart';

void main() {
  late CanvasSettingsRepository settings;

  setUp(() => settings = CanvasSettingsRepository());
  tearDown(() => settings.dispose());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showCanvasSettingsSheet(
                  context,
                  settings: settings.settings,
                  onInkColorChanged: settings.setInkColor,
                  onPaperChanged: settings.setPaper,
                  onShowPenTipChanged: settings.setShowPenTip,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Finder swatch(InkColor inkColor) => find.byKey(ValueKey(inkColor));

  Finder checkIn(InkColor inkColor) =>
      find.descendant(of: swatch(inkColor), matching: find.byIcon(Icons.check));

  testWidgets('shows the title, the three sections and 5 colours', (
    tester,
  ) async {
    await openSheet(tester);

    for (final text in [
      'Canvas & Pen Settings',
      'Ink colour',
      'Paper background',
      'Display & Coordinates',
      'Show Pen Tip Indicator',
      'Blank',
      'Dot grid',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    for (final inkColor in InkColor.values) {
      expect(swatch(inkColor), findsOneWidget);
    }
    expect(checkIn(InkColor.black), findsOneWidget);
  });

  testWidgets('swatches are labelled buttons with a selected state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openSheet(tester);

    expect(
      tester.getSemantics(swatch(InkColor.black)),
      isSemantics(
        label: 'Ink colour, Black',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(swatch(InkColor.blue)),
      isSemantics(label: 'Ink colour, Blue', isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('choosing a colour updates the settings and moves the check', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(swatch(InkColor.blue));
    await tester.pump();

    expect(settings.settings.value.inkColor, InkColor.blue);
    expect(checkIn(InkColor.blue), findsOneWidget);
    expect(checkIn(InkColor.black), findsNothing);
  });

  testWidgets('choosing Dot grid paper updates the settings', (tester) async {
    await openSheet(tester);

    expect(settings.settings.value.paper, PaperBackground.blank);

    await tester.tap(find.text('Dot grid'));
    await tester.pump();

    expect(settings.settings.value.paper, PaperBackground.dotGrid);
  });

  testWidgets('the pen tip switch updates the settings', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(settings.settings.value.showPenTip, isFalse);
  });

  testWidgets('tapping outside closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Canvas & Pen Settings'), findsNothing);
  });
}
