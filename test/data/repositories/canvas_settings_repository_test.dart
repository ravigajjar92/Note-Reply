import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/data/repositories/canvas_settings_repository.dart';
import 'package:note_replay_animation/domain/models/canvas_settings.dart';

void main() {
  late CanvasSettingsRepository repository;
  late int notifications;

  setUp(() {
    repository = CanvasSettingsRepository();
    notifications = 0;
    repository.settings.addListener(() => notifications++);
  });

  tearDown(() => repository.dispose());

  test('starts with black ink, blank paper and the pen tip on', () {
    expect(
      repository.settings.value,
      const CanvasSettings(
        inkColor: InkColor.black,
        paper: PaperBackground.blank,
        showPenTip: true,
      ),
    );
  });

  test('setInkColor changes only the ink colour and notifies once', () {
    repository.setInkColor(InkColor.blue);

    expect(repository.settings.value.inkColor, InkColor.blue);
    expect(repository.settings.value.paper, PaperBackground.blank);
    expect(notifications, 1);
  });

  test('setPaper changes the paper and notifies once', () {
    repository.setPaper(PaperBackground.dotGrid);

    expect(repository.settings.value.paper, PaperBackground.dotGrid);
    expect(notifications, 1);
  });

  test('setShowPenTip changes the switch and notifies once', () {
    repository.setShowPenTip(false);

    expect(repository.settings.value.showPenTip, isFalse);
    expect(notifications, 1);
  });

  test('setting the current value does not notify', () {
    repository
      ..setInkColor(InkColor.black)
      ..setPaper(PaperBackground.blank)
      ..setShowPenTip(true);

    expect(notifications, 0);
  });
}
