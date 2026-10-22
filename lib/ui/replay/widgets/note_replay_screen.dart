import 'package:flutter/material.dart';

import '../../../data/repositories/canvas_settings_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/note_summary.dart';
import '../../core/ink_style.dart';
import '../view_models/frame_clock.dart';
import '../view_models/note_replay_view_model.dart';
import 'canvas_settings_sheet.dart';
import 'playback_controls.dart';
import 'replay_canvas.dart';
import 'replay_progress_bar.dart';

/// The Note detail screen: replays a note's handwriting on a canvas.
///
/// Built once per route. During playback only the canvas and the progress
/// bar repaint; the app bar, button and layout don't rebuild.
class NoteReplayScreen extends StatefulWidget {
  const NoteReplayScreen({
    super.key,
    required this.note,
    required this.noteRepository,
    required this.settingsRepository,
    this.autoPlay = false,
  });

  final NoteSummary note;
  final NoteRepository noteRepository;
  final CanvasSettingsRepository settingsRepository;

  /// Whether to start playing as soon as the note loads, as after writing a
  /// new note. Otherwise the screen opens on the complete note.
  final bool autoPlay;

  @override
  State<NoteReplayScreen> createState() => _NoteReplayScreenState();
}

class _NoteReplayScreenState extends State<NoteReplayScreen>
    with SingleTickerProviderStateMixin {
  late final NoteReplayViewModel _viewModel = NoteReplayViewModel(
    note: widget.note,
    noteRepository: widget.noteRepository,
    settingsRepository: widget.settingsRepository,
    clock: TickerFrameClock(this),
  );

  @override
  void initState() {
    super.initState();
    _viewModel.load(autoPlay: widget.autoPlay);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _openSettings() {
    showCanvasSettingsSheet(
      context,
      settings: _viewModel.settings,
      onInkColorChanged: _viewModel.setInkColor,
      onPaperChanged: _viewModel.setPaper,
      onShowPenTipChanged: _viewModel.setShowPenTip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Canvas & Pen Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _viewModel.loadState,
        builder: (context, state, _) => switch (state) {
          NoteLoading() => const ColoredBox(
            color: InkStyle.paperColor,
            child: Center(child: CircularProgressIndicator()),
          ),
          NoteLoadError() => _LoadError(onRetry: _viewModel.load),
          NoteReady(:final geometry) => ValueListenableBuilder(
            valueListenable: _viewModel.settings,
            builder: (context, settings, _) => ReplayCanvas(
              geometry: geometry,
              frame: _viewModel.frame,
              committedStrokes: _viewModel.committedStrokes,
              settings: settings,
              semanticLabel: 'Handwriting of ${widget.note.title}',
              penWritingMicros: _viewModel.penWritingMicros,
              penLiftMicros: _viewModel.penLiftMicros,
            ),
          ),
        },
      ),
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _viewModel.loadState,
        builder: (context, state, _) => state is NoteReady
            ? PlaybackButton(
                status: _viewModel.status,
                onPressed: _viewModel.togglePlayback,
              )
            : const SizedBox.shrink(),
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: _viewModel.loadState,
        builder: (context, state, _) => state is NoteReady
            ? ReplayProgressBar(
                frame: _viewModel.frame,
                clockTenths: _viewModel.clockTenths,
                duration: _viewModel.duration,
                onSeekStart: _viewModel.beginSeek,
                onSeek: _viewModel.seekTo,
                onSeekEnd: _viewModel.endSeek,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't open this note.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
