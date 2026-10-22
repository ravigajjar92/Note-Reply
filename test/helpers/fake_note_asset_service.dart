import 'dart:async';

import 'package:note_replay_animation/data/services/note_asset_service.dart';

/// A [NoteAssetService] backed by in-memory assets, with call counters and
/// switches for failure and delay.
class FakeNoteAssetService implements NoteAssetService {
  FakeNoteAssetService({
    this.assets = const [],
    this.csvByPath = const {},
    this.listError,
  });

  List<String> assets;
  Map<String, String> csvByPath;

  /// When set, [listAssets] throws it.
  Exception? listError;

  /// When set, [listAssets] waits for it to complete before answering.
  Completer<void>? listGate;

  int listCalls = 0;
  int loadCalls = 0;

  @override
  Future<List<String>> listAssets() async {
    listCalls++;
    if (listGate case final gate?) await gate.future;
    if (listError case final error?) throw error;
    return assets;
  }

  @override
  Future<String> loadCsv(String assetPath) async {
    loadCalls++;
    return csvByPath[assetPath] ??
        (throw Exception('No asset at $assetPath'));
  }
}

/// Asset paths for `note_1` … `note_[count]`.
List<String> noteAssets(int count) => [
  for (var i = 1; i <= count; i++) 'assets/notes/note_$i.csv',
];
