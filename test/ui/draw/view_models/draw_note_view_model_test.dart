import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/canvas_settings_repository.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/domain/models/note.dart';
import 'package:note_replay_animation/domain/models/note_summary.dart';
import 'package:note_replay_animation/ui/draw/view_models/draw_note_view_model.dart';
import 'package:note_replay_animation/utils/result.dart';

import '../../../helpers/fake_note_asset_service.dart';

void main() {
  late NoteRepository repository;
  late CanvasSettingsRepository settings;
  late DrawNoteViewModel viewModel;

  setUp(() {
    repository = NoteRepository(assetService: FakeNoteAssetService());
    settings = CanvasSettingsRepository();
    viewModel = DrawNoteViewModel(
      noteRepository: repository,
      settingsRepository: settings,
    );
  });

  tearDown(() {
    viewModel.dispose();
    settings.dispose();
  });

  Duration ms(int milliseconds) => Duration(milliseconds: milliseconds);

  /// Draws a horizontal stroke with [pointer], from x = [x] over 3 moves.
  void drawStroke({int pointer = 1, double x = 0, int startMs = 0}) {
    viewModel.penDown(pointer, Offset(x, 10), ms(startMs));
    for (var i = 1; i <= 3; i++) {
      viewModel.penMove(pointer, Offset(x + i * 10, 10), ms(startMs + i * 8));
    }
    viewModel.penUp(pointer);
  }

  test('starts with nothing written', () {
    expect(viewModel.strokeCount.value, 0);
    expect(viewModel.hasInk.value, isFalse);
  });

  test('records positions in millimetres', () {
    viewModel
      ..penDown(1, const Offset(160, 320), Duration.zero)
      ..penMove(1, const Offset(320, 320), ms(10));

    // 160 logical pixels = 1 inch = 25.4 mm.
    expect(viewModel.recording.activePoints, [
      closeTo(25.4, 1e-4),
      closeTo(50.8, 1e-4),
      closeTo(50.8, 1e-4),
      closeTo(50.8, 1e-4),
    ]);
  });

  test('pen down shows ink at once; pen up finishes the stroke', () {
    var activeSignals = 0;
    viewModel.activeStroke.addListener(() => activeSignals++);

    viewModel.penDown(1, Offset.zero, Duration.zero);
    expect(viewModel.hasInk.value, isTrue);
    expect(viewModel.strokeCount.value, 0);

    viewModel
      ..penMove(1, const Offset(5, 5), ms(8))
      ..penUp(1);
    expect(viewModel.strokeCount.value, 1);
    expect(activeSignals, 3);
  });

  test('ignores a second pointer while one is drawing', () {
    viewModel
      ..penDown(1, Offset.zero, Duration.zero)
      ..penDown(2, const Offset(100, 100), ms(1))
      ..penMove(2, const Offset(110, 110), ms(2))
      ..penUp(2)
      ..penMove(1, const Offset(5, 0), ms(8))
      ..penUp(1);

    expect(viewModel.strokeCount.value, 1);
    expect(viewModel.recording.strokePoints(0), hasLength(4));
  });

  test('undo and clear update the stroke count and ink flag', () {
    drawStroke();
    drawStroke(x: 50, startMs: 500);

    viewModel.undo();
    expect(viewModel.strokeCount.value, 1);
    expect(viewModel.hasInk.value, isTrue);

    viewModel.clear();
    expect(viewModel.strokeCount.value, 0);
    expect(viewModel.hasInk.value, isFalse);
  });

  test('finish adds the note to the repository with real timing', () async {
    drawStroke();
    drawStroke(x: 50, startMs: 500);

    final summary = await viewModel.finish();

    expect(
      (summary as Ok<NoteSummary>).value,
      const NoteSummary(id: 'drawn_1', title: 'New note 1'),
    );
    final result = await repository.loadNote('drawn_1');
    final note = (result as Ok<Note>).value;
    expect(note.strokeCount, 2);
    expect(note.pointCount, 8);
    expect(note.strokeT0[1], closeTo(0.5, 1e-9));
    expect(note.duration, closeTo(0.524, 1e-9));
  });
}
