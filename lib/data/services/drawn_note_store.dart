/// Where notes drawn in the app are saved: CSV text keyed by note id.
abstract interface class DrawnNoteStore {
  /// Ids of every saved note, in no particular order.
  Future<List<String>> listIds();

  /// The CSV of the note with [id].
  Future<String> read(String id);

  /// Saves [csv] as the note with [id], replacing any earlier version.
  Future<void> write(String id, String csv);
}

/// Keeps drawn notes in memory only, so they're lost when the app closes.
/// Used on the web, where there's no file system, and in tests.
class InMemoryDrawnNoteStore implements DrawnNoteStore {
  final _csvById = <String, String>{};

  @override
  Future<List<String>> listIds() async => _csvById.keys.toList();

  @override
  Future<String> read(String id) async =>
      _csvById[id] ?? (throw StateError('No drawn note "$id".'));

  @override
  Future<void> write(String id, String csv) async => _csvById[id] = csv;
}
