import 'package:flutter/foundation.dart';

import '../../../data/repositories/note_repository.dart';
import '../../../domain/models/note_summary.dart';
import '../../../utils/result.dart';

/// What the note list is showing.
sealed class NoteListState {
  const NoteListState();
}

/// The note list is being read.
final class NoteListLoading extends NoteListState {
  const NoteListLoading();
}

/// At least one note was found.
final class NoteListData extends NoteListState {
  const NoteListData(this.notes);

  /// Every note, before search filtering.
  final List<NoteSummary> notes;
}

/// No notes were found.
final class NoteListEmpty extends NoteListState {
  const NoteListEmpty();
}

/// The note list couldn't be read.
final class NoteListError extends NoteListState {
  const NoteListError(this.error);

  final Exception error;
}

/// ViewModel for the Home screen: loads the note list and filters it by the
/// search text.
class NoteListViewModel extends ChangeNotifier {
  NoteListViewModel({required this._repository});

  final NoteRepository _repository;

  NoteListState _state = const NoteListLoading();
  String _query = '';
  List<NoteSummary> _visibleNotes = const [];
  bool _disposed = false;

  /// What the note list is showing.
  NoteListState get state => _state;

  /// The current search text, as typed.
  String get query => _query;

  /// The notes matching [query], in list order. Empty unless [state] is
  /// [NoteListData].
  List<NoteSummary> get visibleNotes => _visibleNotes;

  /// Loads the note list. Called when the Home screen opens, and again by
  /// Retry.
  Future<void> load() async {
    _state = const NoteListLoading();
    _applySearch();
    notifyListeners();
    await _fetch();
  }

  /// Re-reads the list without showing the loading state, for example after
  /// a note is added. The search is kept.
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final result = await _repository.listNotes();
    if (_disposed) return;
    _state = switch (result) {
      Ok(value: final notes) when notes.isEmpty => const NoteListEmpty(),
      Ok(value: final notes) => NoteListData(notes),
      Error(:final error) => NoteListError(error),
    };
    _applySearch();
    notifyListeners();
  }

  /// Filters the list to notes whose title contains [query], ignoring case
  /// and leading or trailing spaces.
  void search(String query) {
    if (query == _query) return;
    _query = query;
    _applySearch();
    notifyListeners();
  }

  /// Shows every note again.
  void clearSearch() => search('');

  void _applySearch() {
    final state = _state;
    if (state is! NoteListData) {
      _visibleNotes = const [];
      return;
    }
    final needle = _query.trim().toLowerCase();
    _visibleNotes = needle.isEmpty
        ? state.notes
        : List.unmodifiable(
            state.notes.where((n) => n.title.toLowerCase().contains(needle)),
          );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
