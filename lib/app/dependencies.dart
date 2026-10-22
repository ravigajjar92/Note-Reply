import 'package:flutter/foundation.dart';

import '../data/repositories/canvas_settings_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/services/drawn_note_store.dart';
import '../data/services/file_drawn_note_store.dart';
import '../data/services/note_asset_service.dart';

/// The composition root: builds each service and repository once and hands
/// them to the UI through constructors.
final class Dependencies {
  Dependencies({
    NoteRepository? noteRepository,
    CanvasSettingsRepository? canvasSettingsRepository,
  }) : noteRepository =
           noteRepository ??
           NoteRepository(
             assetService: NoteAssetService(),
             drawnNoteStore: _platformDrawnNoteStore(),
           ),
       canvasSettingsRepository =
           canvasSettingsRepository ?? CanvasSettingsRepository();

  /// Files in the app's documents folder, so drawn notes survive restarts.
  /// The web has no file system, so there they're kept in memory only.
  static DrawnNoteStore _platformDrawnNoteStore() =>
      kIsWeb ? InMemoryDrawnNoteStore() : FileDrawnNoteStore();

  final NoteRepository noteRepository;
  final CanvasSettingsRepository canvasSettingsRepository;
}
