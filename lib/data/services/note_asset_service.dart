import 'package:flutter/services.dart';

/// Reads note files from the app's asset bundle.
class NoteAssetService {
  NoteAssetService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Returns the path of every asset in the bundle's manifest.
  Future<List<String>> listAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    return manifest.listAssets();
  }

  /// Returns the text of the CSV at [assetPath].
  Future<String> loadCsv(String assetPath) => _bundle.loadString(assetPath);
}
