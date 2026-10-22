/// A note as shown in the note list: enough to identify and open it, without
/// parsing its CSV. Notes drawn in the app have no CSV.
final class NoteSummary {
  const NoteSummary({
    required this.id,
    required this.title,
    this.assetPath,
  });

  /// The file name without extension, for example `note_1`.
  final String id;

  /// The display title, for example `Note 1`.
  final String title;

  /// The asset holding the note's CSV, for example `assets/notes/note_1.csv`.
  /// Null for a note drawn in the app.
  final String? assetPath;

  @override
  bool operator ==(Object other) =>
      other is NoteSummary &&
      other.id == id &&
      other.title == title &&
      other.assetPath == assetPath;

  @override
  int get hashCode => Object.hash(id, title, assetPath);

  @override
  String toString() => 'NoteSummary($id, $title, $assetPath)';
}
