import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/app/app.dart';
import 'package:note_replay_animation/app/dependencies.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/data/services/note_asset_service.dart';

void main() {
  testWidgets('the app starts on Home and lists the 5 bundled notes', (
    tester,
  ) async {
    // The real asset bundle, with drawn notes kept in memory: saving to
    // files needs a platform plugin that tests don't have.
    await tester.pumpWidget(
      App(
        dependencies: Dependencies(
          noteRepository: NoteRepository(assetService: NoteAssetService()),
        ),
      ),
    );
    // The real asset bundle reads files, which fake time doesn't wait for.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Notes'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(5));
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Note $i'), findsOneWidget);
    }
  });
}
