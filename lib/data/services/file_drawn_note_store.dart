import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'drawn_note_store.dart';

/// Saves drawn notes as `<id>.csv` files in a `drawn_notes` folder inside the
/// app's documents directory, so they survive restarts.
class FileDrawnNoteStore implements DrawnNoteStore {
  /// [baseDirectory] defaults to the app's documents directory. Tests pass a
  /// temporary one.
  FileDrawnNoteStore({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;
  Directory? _directory;

  static const _extension = '.csv';

  Future<Directory> _notesDirectory() async {
    if (_directory case final directory?) return directory;
    final base = await _baseDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}drawn_notes',
    );
    await directory.create(recursive: true);
    return _directory = directory;
  }

  Future<File> _file(String id) async {
    final directory = await _notesDirectory();
    return File('${directory.path}${Platform.pathSeparator}$id$_extension');
  }

  @override
  Future<List<String>> listIds() async {
    final directory = await _notesDirectory();
    final ids = <String>[];
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.endsWith(_extension)) {
        ids.add(name.substring(0, name.length - _extension.length));
      }
    }
    return ids;
  }

  @override
  Future<String> read(String id) async => (await _file(id)).readAsString();

  @override
  Future<void> write(String id, String csv) async {
    final file = await _file(id);
    // Write a temporary file and rename it over the real one, so a crash
    // mid-write never leaves a half-written note behind.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(csv, flush: true);
    await temporary.rename(file.path);
  }
}
