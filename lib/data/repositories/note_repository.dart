import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/models/ink_recording.dart';
import '../../domain/models/note.dart';
import '../../domain/models/note_summary.dart';
import '../../utils/result.dart';
import '../parsers/note_csv_parser.dart';
import '../parsers/note_csv_writer.dart';
import '../services/drawn_note_store.dart';
import '../services/note_asset_service.dart';

/// Thrown when a note id doesn't match any bundled or drawn note.
final class NoteNotFoundException implements Exception {
  const NoteNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'NoteNotFoundException: no note with id "$id".';
}

/// Lists and loads notes: the bundled CSVs, and notes drawn in the app.
///
/// Listing reads the asset manifest and the drawn-note store once, then
/// serves from a cache. A note's CSV is parsed the first time [loadNote] asks
/// for it. Drawn notes are saved through [DrawnNoteStore] as soon as they're
/// added, and listed after the bundled ones.
class NoteRepository {
  /// [drawnNoteStore] defaults to one that keeps drawn notes in memory only.
  NoteRepository({
    required this._assetService,
    DrawnNoteStore? drawnNoteStore,
  }) : _drawnNoteStore = drawnNoteStore ?? InMemoryDrawnNoteStore();

  /// The asset folder that holds note CSVs.
  static const notesDirectory = 'assets/notes/';

  static const _drawnIdPrefix = 'drawn_';

  final NoteAssetService _assetService;
  final DrawnNoteStore _drawnNoteStore;
  List<NoteSummary>? _bundled;
  List<NoteSummary>? _drawn;
  final _notes = <String, Note>{};

  /// Returns every note under [notesDirectory], sorted by file name with
  /// numbers in natural order, followed by the drawn notes, oldest first.
  Future<Result<List<NoteSummary>>> listNotes() async {
    try {
      final bundled = _bundled ??= await _listBundled();
      final drawn = _drawn ??= await _listDrawn();
      return Result.ok(
        drawn.isEmpty ? bundled : List.unmodifiable([...bundled, ...drawn]),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  /// Saves the finished strokes of [recording] as a new note titled
  /// "New note N", and returns its summary. N continues from the highest
  /// saved number. If saving fails, nothing is added.
  Future<Result<NoteSummary>> addDrawnNote(InkRecording recording) async {
    if (await listNotes() case Error(:final error)) return Result.error(error);
    final drawn = _drawn!;
    final number =
        drawn.fold(0, (highest, s) => math.max(highest, _drawnNumber(s.id)!)) +
        1;
    final id = '$_drawnIdPrefix$number';
    final note = recording.toNote(id);
    try {
      await _drawnNoteStore.write(id, NoteCsvWriter.write(note));
    } on Exception catch (error) {
      return Result.error(error);
    }
    final summary = _drawnSummary(id, number);
    _notes[id] = note;
    drawn.add(summary);
    return Result.ok(summary);
  }

  /// Returns the parsed note with the given [id].
  Future<Result<Note>> loadNote(String id) async {
    if (_notes[id] case final note?) return Result.ok(note);
    switch (await listNotes()) {
      case Error(:final error):
        return Result.error(error);
      case Ok(value: final summaries):
        final summary = summaries.where((s) => s.id == id).firstOrNull;
        if (summary == null) return Result.error(NoteNotFoundException(id));
        try {
          final csv = switch (summary.assetPath) {
            final assetPath? => await _assetService.loadCsv(assetPath),
            null => await _drawnNoteStore.read(id),
          };
          final note = await compute(_parseNote, (id, csv));
          return Result.ok(_notes[id] = note);
        } on Exception catch (error) {
          return Result.error(error);
        }
    }
  }

  Future<List<NoteSummary>> _listBundled() async {
    final paths = await _assetService.listAssets();
    final summaries = [
      for (final path in paths)
        if (path.startsWith(notesDirectory) && path.endsWith('.csv'))
          _summaryFor(path),
    ]..sort((a, b) => _compareNatural(a.id, b.id));
    return List.unmodifiable(summaries);
  }

  Future<List<NoteSummary>> _listDrawn() async {
    final ids = await _drawnNoteStore.listIds();
    return [
      for (final id in ids)
        if (_drawnNumber(id) case final number?) _drawnSummary(id, number),
    ]..sort((a, b) => _drawnNumber(a.id)!.compareTo(_drawnNumber(b.id)!));
  }

  /// `drawn_12` → 12; null for any other id.
  static int? _drawnNumber(String id) => id.startsWith(_drawnIdPrefix)
      ? int.tryParse(id.substring(_drawnIdPrefix.length))
      : null;

  static NoteSummary _drawnSummary(String id, int number) =>
      NoteSummary(id: id, title: 'New note $number');

  static Note _parseNote((String, String) input) =>
      NoteCsvParser.parse(input.$1, input.$2);

  /// `assets/notes/note_1.csv` → id `note_1`, title `Note 1`.
  static NoteSummary _summaryFor(String path) {
    final id = path.substring(
      path.lastIndexOf('/') + 1,
      path.length - '.csv'.length,
    );
    final words = id.replaceAll('_', ' ').trim();
    final title = words.isEmpty
        ? id
        : words[0].toUpperCase() + words.substring(1);
    return NoteSummary(id: id, title: title, assetPath: path);
  }

  static final _digitsOrText = RegExp(r'\d+|\D+');

  /// Compares strings so runs of digits are ordered by value:
  /// `note_9` < `note_10`.
  static int _compareNatural(String a, String b) {
    final partsA = _digitsOrText.allMatches(a).map((m) => m[0]!).toList();
    final partsB = _digitsOrText.allMatches(b).map((m) => m[0]!).toList();
    for (var i = 0; i < partsA.length && i < partsB.length; i++) {
      final numberA = int.tryParse(partsA[i]);
      final numberB = int.tryParse(partsB[i]);
      final order = numberA != null && numberB != null
          ? numberA.compareTo(numberB)
          : partsA[i].compareTo(partsB[i]);
      if (order != 0) return order;
    }
    return partsA.length.compareTo(partsB.length);
  }
}
