import 'package:flutter/foundation.dart';

import '../../domain/models/canvas_settings.dart';

/// Holds the canvas settings for the app's lifetime, shared by every note.
///
/// Settings live in memory only. Saving them across restarts means replacing
/// this class with a stored version; its users don't change.
class CanvasSettingsRepository {
  final _settings = ValueNotifier(const CanvasSettings());

  /// The current settings. Notifies only when a value actually changes.
  ValueListenable<CanvasSettings> get settings => _settings;

  void setInkColor(InkColor inkColor) =>
      _settings.value = _settings.value.copyWith(inkColor: inkColor);

  void setPaper(PaperBackground paper) =>
      _settings.value = _settings.value.copyWith(paper: paper);

  void setShowPenTip(bool showPenTip) =>
      _settings.value = _settings.value.copyWith(showPenTip: showPenTip);

  void dispose() => _settings.dispose();
}
