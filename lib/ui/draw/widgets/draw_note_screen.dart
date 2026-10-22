import 'package:flutter/material.dart';

import '../../../data/repositories/canvas_settings_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/note_summary.dart';
import '../../../utils/result.dart';
import '../../core/ink_style.dart';
import '../../replay/widgets/paper_painter.dart';
import '../view_models/draw_note_view_model.dart';
import 'recording_painters.dart';

/// The New note screen: a fresh canvas to write on. Animate saves the note
/// and replaces this screen with its replay.
class DrawNoteScreen extends StatefulWidget {
  const DrawNoteScreen({
    super.key,
    required this.noteRepository,
    required this.settingsRepository,
    required this.replayBuilder,
  });

  final NoteRepository noteRepository;
  final CanvasSettingsRepository settingsRepository;

  /// Builds the replay screen for the finished note.
  final Widget Function(NoteSummary note) replayBuilder;

  @override
  State<DrawNoteScreen> createState() => _DrawNoteScreenState();
}

class _DrawNoteScreenState extends State<DrawNoteScreen> {
  late final _viewModel = DrawNoteViewModel(
    noteRepository: widget.noteRepository,
    settingsRepository: widget.settingsRepository,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _animate() async {
    setState(() => _saving = true);
    final result = await _viewModel.finish();
    if (!mounted) return;
    switch (result) {
      case Ok(value: final note):
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => widget.replayBuilder(note)),
        );
      case Error():
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save the note. Try again.")),
        );
    }
  }

  /// Back with nothing written leaves at once; otherwise asks first.
  Future<void> _confirmLeave() async {
    final navigator = Navigator.of(context);
    if (!_viewModel.hasInk.value) {
      navigator.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this note?'),
        content: const Text("What you've written will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep writing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard ?? false) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New note'),
          actions: [
            ValueListenableBuilder(
              valueListenable: _viewModel.strokeCount,
              builder: (context, count, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Undo',
                    onPressed: count > 0 ? _viewModel.undo : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear',
                    onPressed: count > 0 ? _viewModel.clear : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: ValueListenableBuilder(
          valueListenable: _viewModel.settings,
          builder: (context, settings, _) {
            final ink = InkStyle.strokePaint(settings.inkColor);
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _viewModel.penDown(
                event.pointer,
                event.localPosition,
                event.timeStamp,
              ),
              onPointerMove: (event) => _viewModel.penMove(
                event.pointer,
                event.localPosition,
                event.timeStamp,
              ),
              onPointerUp: (event) => _viewModel.penUp(event.pointer),
              onPointerCancel: (event) => _viewModel.penUp(event.pointer),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: PaperPainter(paper: settings.paper),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: RecordedInkPainter(
                        recording: _viewModel.recording,
                        strokeCount: _viewModel.strokeCount,
                        ink: ink,
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: LiveInkPainter(
                        recording: _viewModel.recording,
                        activeStroke: _viewModel.activeStroke,
                        ink: ink,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: ValueListenableBuilder(
                      valueListenable: _viewModel.hasInk,
                      builder: (context, hasInk, _) => hasInk
                          ? const SizedBox.shrink()
                          : Center(
                              child: Text(
                                'Write anything',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: ValueListenableBuilder(
          valueListenable: _viewModel.strokeCount,
          builder: (context, count, _) => count > 0
              ? FloatingActionButton.extended(
                  // Disabled while saving, so a double tap saves once.
                  onPressed: _saving ? null : _animate,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Animate'),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
