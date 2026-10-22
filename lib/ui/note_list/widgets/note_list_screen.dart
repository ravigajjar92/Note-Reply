import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../domain/models/note_summary.dart';
import '../view_models/note_list_view_model.dart';

/// The Home screen: a searchable list of note titles. Tapping a note opens
/// its detail screen; the floating button opens a fresh canvas to write a new
/// note.
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({
    super.key,
    required this.viewModel,
    required this.noteDetailBuilder,
    required this.newNoteBuilder,
  });

  final NoteListViewModel viewModel;

  /// Builds the detail screen for a tapped note. Supplied by the app, which
  /// owns the dependencies the detail screen needs.
  final Widget Function(NoteSummary note) noteDetailBuilder;

  /// Builds the screen for writing a new note.
  final Widget Function() newNoteBuilder;

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  static const _maxContentWidth = 600.0;
  static const _searchBarHeight = 56.0;
  static const _searchBarBottomPadding = 12.0;

  final _searchController = TextEditingController();

  NoteListViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    final countBefore = _viewModel.visibleNotes.length;
    _viewModel.search(text);
    final count = _viewModel.visibleNotes.length;
    if (count != countBefore) {
      SemanticsService.sendAnnouncement(View.of(context), switch (count) {
        0 => 'No matching notes',
        1 => '1 note',
        _ => '$count notes',
      }, Directionality.of(context));
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _openNote(NoteSummary note) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.noteDetailBuilder(note)),
    );
  }

  Future<void> _newNote() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => widget.newNoteBuilder()));
    // The new note, if one was made, is now in the repository.
    if (mounted) _viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            _searchBarHeight + _searchBarBottomPadding,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              _searchBarBottomPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => _buildSearchBar(),
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New note',
        onPressed: _newNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SearchBar(
      controller: _searchController,
      enabled: _viewModel.state is NoteListData,
      hintText: 'Search notes',
      leading: const Icon(Icons.search),
      trailing: [
        if (_viewModel.query.isNotEmpty)
          IconButton(
            tooltip: 'Clear search',
            icon: const Icon(Icons.close),
            onPressed: _clearSearch,
          ),
      ],
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }

  Widget _buildBody() {
    return switch (_viewModel.state) {
      NoteListLoading() => const Center(child: CircularProgressIndicator()),
      NoteListEmpty() => const _Message(text: 'No notes yet'),
      NoteListError() => _Message(
        text: "Couldn't load notes.",
        action: FilledButton(
          onPressed: _viewModel.load,
          child: const Text('Retry'),
        ),
      ),
      NoteListData() when _viewModel.visibleNotes.isEmpty => _Message(
        text: 'No notes match "${_viewModel.query.trim()}"',
        action: TextButton(
          onPressed: _clearSearch,
          child: const Text('Clear search'),
        ),
      ),
      NoteListData() => _buildList(_viewModel.visibleNotes),
    };
  }

  Widget _buildList(List<NoteSummary> notes) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // Room below the last note so the floating button never covers it.
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: notes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final note = notes[index];
            return ListTile(
              key: ValueKey(note.id),
              title: Text(note.title),
              onTap: () => _openNote(note),
            );
          },
        ),
      ),
    );
  }
}

/// A centred message with an optional action button below it.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (action case final action?) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
