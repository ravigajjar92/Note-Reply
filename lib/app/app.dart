import 'package:flutter/material.dart';

import '../domain/models/note_summary.dart';
import '../ui/core/theme.dart';
import '../ui/draw/widgets/draw_note_screen.dart';
import '../ui/note_list/view_models/note_list_view_model.dart';
import '../ui/note_list/widgets/note_list_screen.dart';
import '../ui/replay/widgets/note_replay_screen.dart';
import 'dependencies.dart';

/// The root widget. Owns the Home screen's ViewModel and the canvas
/// settings for the app's lifetime.
class App extends StatefulWidget {
  const App({super.key, required this.dependencies});

  final Dependencies dependencies;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final _noteListViewModel = NoteListViewModel(
    repository: widget.dependencies.noteRepository,
  );

  @override
  void dispose() {
    _noteListViewModel.dispose();
    widget.dependencies.canvasSettingsRepository.dispose();
    super.dispose();
  }

  Widget _replayScreen(NoteSummary note, {bool autoPlay = false}) =>
      NoteReplayScreen(
        note: note,
        noteRepository: widget.dependencies.noteRepository,
        settingsRepository: widget.dependencies.canvasSettingsRepository,
        autoPlay: autoPlay,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      home: NoteListScreen(
        viewModel: _noteListViewModel,
        noteDetailBuilder: _replayScreen,
        newNoteBuilder: () => DrawNoteScreen(
          noteRepository: widget.dependencies.noteRepository,
          settingsRepository: widget.dependencies.canvasSettingsRepository,
          replayBuilder: (note) => _replayScreen(note, autoPlay: true),
        ),
      ),
    );
  }
}
