import 'dart:typed_data';

import '../../../domain/models/note.dart';

/// A note prepared for drawing: one view of the point data per stroke, built
/// once so painters never copy or rebuild geometry.
final class NoteGeometry {
  NoteGeometry(this.note)
    : strokes = List.unmodifiable([
        for (var s = 0; s < note.strokeCount; s++)
          Float32List.sublistView(
            note.xy,
            note.strokeStart[s] * 2,
            note.strokeStart[s + 1] * 2,
          ),
      ]);

  final Note note;

  /// Interleaved `x, y` points of each stroke, in millimetres. Views share
  /// [Note.xy]; nothing is copied.
  final List<Float32List> strokes;
}
