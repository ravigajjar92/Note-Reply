import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../view_models/note_replay_view_model.dart';

/// The floating button that plays, pauses, resumes and replays the note.
///
/// Rebuilds only when the playback status changes, never per frame.
class PlaybackButton extends StatelessWidget {
  const PlaybackButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  final ValueListenable<PlaybackStatus> status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: status,
      builder: (context, status, _) {
        final (icon, tooltip) = switch (status) {
          PlaybackStatus.ready => (Icons.play_arrow, 'Play'),
          PlaybackStatus.playing => (Icons.pause, 'Pause'),
          PlaybackStatus.paused => (Icons.play_arrow, 'Resume'),
          PlaybackStatus.completed => (Icons.replay, 'Replay'),
        };
        return FloatingActionButton(
          tooltip: tooltip,
          onPressed: onPressed,
          child: Icon(icon),
        );
      },
    );
  }
}
