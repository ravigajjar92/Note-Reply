import 'dart:async';
import 'dart:io';

import 'package:note_replay_animation/data/parsers/note_csv_parser.dart';
import 'package:note_replay_animation/data/repositories/note_repository.dart';
import 'package:note_replay_animation/domain/models/note.dart';
import 'package:note_replay_animation/domain/models/note_summary.dart';
import 'package:note_replay_animation/utils/result.dart';

import 'fake_note_asset_service.dart';

/// Two strokes over 0.7 s:
/// - stroke 0: (0, 0) → (3, 0) mm, samples at 0.0, 0.1, 0.2, 0.3 s
/// - stroke 1: (3, 1) → (3, 3) mm, samples at 0.5, 0.6, 0.7 s
const twoStrokeCsv =
    'x,y,t,stroke\n'
    '0,0,1.0,0\n'
    '0.001,0,1.1,0\n'
    '0.002,0,1.2,0\n'
    '0.003,0,1.3,0\n'
    '0.003,0.001,1.5,1\n'
    '0.003,0.002,1.6,1\n'
    '0.003,0.003,1.7,1\n';

/// The bundled note_1 CSV ("Hello team!", about 6 s).
String note1Csv() => File('assets/notes/note_1.csv').readAsStringSync();

const testSummary = NoteSummary(
  id: 'note_1',
  title: 'Note 1',
  assetPath: 'assets/notes/note_1.csv',
);

/// A [NoteRepository] that parses [csv] on the calling thread, so tests don't
/// wait on a background isolate.
class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository({this.csv = twoStrokeCsv})
    : super(assetService: FakeNoteAssetService());

  String csv;

  /// When set, [loadNote] fails with it.
  Exception? loadError;

  /// When set, [loadNote] waits for it before answering.
  Completer<void>? loadGate;

  int loadCalls = 0;

  @override
  Future<Result<Note>> loadNote(String id) async {
    loadCalls++;
    if (loadGate case final gate?) await gate.future;
    if (loadError case final error?) return Result.error(error);
    return Result.ok(NoteCsvParser.parse(id, csv));
  }
}
