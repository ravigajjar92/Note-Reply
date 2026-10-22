# Note Replay Animation — Screens Plan

Status: Approved · Date: 2026-10-21 · Builds on [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md)

This document turns the screen requirements into a plan that fits the approved MVVM
architecture. It currently covers the **Home screen**.

---

## 1. Home screen

### 1.1 Requirements

| # | Requirement |
|---|---|
| H1 | App bar with the title **"Notes"** |
| H2 | A list of notes |
| H3 | The 5 bundled CSV files load into the list by default, showing **only the title** |
| H4 | Tapping a note opens the **Note detail screen** for that note |
| H5 | A **search bar** on the Home screen to find notes |
| H6 | A floating **Add** button that opens a fresh canvas to write a new note, then animates it. See [NEW_NOTE_PLAN.md](NEW_NOTE_PLAN.md) |

### 1.2 What the requirements leave open, and the defaults chosen

| Question | Decision | Why |
|---|---|---|
| A CSV has no title field, so where does the title come from? | **From the file name**: `note_1.csv` → **"Note 1"** (drop the extension, replace `_` with a space, capitalise the first letter) | Needs no extra data. Reading the handwritten text would need handwriting recognition, which is out of scope. A `notes.json` file with real titles can replace this later without changing the screen |
| How are the 5 files found? | Read the asset manifest (`AssetManifest.loadFromAssetBundle(rootBundle)`) and keep the files under `assets/notes/` that end in `.csv` | Nothing is hard-coded. Dropping a 6th CSV into `assets/notes/` makes it appear without code changes |
| Order | **Natural sort** by file name | `note_10` comes after `note_9`, not after `note_1` |
| Does Home parse the CSVs? | **No.** Home only lists file names. A CSV is parsed when its note is opened | Home shows only titles, so parsing ~11k rows to show 5 labels would waste startup time. It also stays fast if the notes get large ([ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md), large-data discussion) |
| What is the "note button"? | The **whole list row** is the tap target (`ListTile.onTap`) | It's the standard Material pattern, it's a larger target than a separate button, and screen readers announce it as one item |
| What else does a row show? | **Title only**: no subtitle, icon or chevron | That's what H3 asks for |
| Navigation | `Navigator.push` with `MaterialPageRoute` | Two screens and no deep links. A routing package isn't needed yet |
| What does search look at? | **The title only** | It's the only text a note has. Searching the handwritten words would need handwriting recognition. If real titles arrive later (`notes.json`), search picks them up automatically |
| How does matching work? | Ignores upper/lower case and leading/trailing spaces, and matches **anywhere in the title**: "3" finds "Note 3", and "note" finds all of them | Simple and predictable for short titles |
| When does the list update? | **As you type**, with no search button and no delay | Filtering 5 titles in memory is instant. A short delay (about 150 ms) can be added if the list ever reaches thousands of notes |
| Where is the search bar? | Always visible, **directly under the app bar title** (Material 3 `SearchBar` in `AppBar.bottom`) | Visible without an extra tap. Material's `SearchAnchor` (search opens a separate overlay) is more than a 5-item list needs |
| Is the search kept? | Yes, when going to a note and coming back. Cleared when the app restarts | The Home screen stays alive under the detail screen, so the search is still there on return |

### 1.3 Change to the architecture

`NoteSummary` was planned as *id, title, duration, stroke count*. Duration and stroke count
can only be known by parsing the CSV, which Home now avoids, so the model becomes:

```dart
final class NoteSummary {
  const NoteSummary({required this.id, required this.title, required this.assetPath});
  final String id;        // 'note_1' (file name without extension)
  final String title;     // 'Note 1'
  final String assetPath; // 'assets/notes/note_1.csv'
}
```

Duration and stroke count can come back later as optional fields if a screen ever shows them.

### 1.4 Layout

```
┌──────────────────────────────┐
│ Notes                        │  AppBar(title: Text('Notes'),
│ ┌──────────────────────────┐ │         bottom: SearchBar(…))
│ │ 🔍 Search notes       ✕  │ │  ✕ (clear) shown only when there is text
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ Note 1                       │  ListTile(title: Text(summary.title), onTap: …)
├──────────────────────────────┤
│ Note 2                       │
├──────────────────────────────┤
│ Note 3                       │
├──────────────────────────────┤
│ Note 4                       │
├──────────────────────────────┤
│ Note 5                       │
└──────────────────────────────┘
```

- `Scaffold` → `AppBar` (title + search bar) + body that switches on the ViewModel's state.
- Search bar: a search icon at the start, the hint "Search notes", and a clear (✕) button
  at the end that appears only when there is text. The keyboard's action key is "Search",
  and pressing it just closes the keyboard, because the list has already updated.
- Scrolling the list closes the keyboard (`keyboardDismissBehavior: onDrag`).
- The body is a `ListView.separated` with `ListTile`s, so it builds rows lazily and stays
  cheap with many notes.
- On wide screens (tablet, desktop), the list is held to a readable width with
  `ConstrainedBox(maxWidth: 600)`, centred.

### 1.5 Screen states

| State | When | UI |
|---|---|---|
| `loading` | Reading the asset manifest | Centred `CircularProgressIndicator`. Usually shown for less than a frame |
| `data` | One or more notes found | The list |
| `empty` | No CSV under `assets/notes/` | Centred text "No notes yet" |
| `error` | The manifest can't be read | Centred message + **Retry** button that runs the load command again |

How the search bar behaves in each state:

| State | Search bar | Body |
|---|---|---|
| `loading`, `empty`, `error` | Shown but **disabled**, since there's nothing to search | As in the table above |
| `data`, search empty | Enabled | All notes |
| `data`, search matches notes | Enabled | Only the matching notes, in the same order |
| `data`, search matches nothing | Enabled | Centred text **"No notes match "…""** with a **Clear search** button. This is different from `empty`: notes exist, the search just hides them all |

These are a sealed type, so the View's `switch` must handle every case:

```dart
sealed class NoteListState {}
final class NoteListLoading extends NoteListState {}
final class NoteListData extends NoteListState { final List<NoteSummary> notes; … }
final class NoteListEmpty extends NoteListState {}
final class NoteListError extends NoteListState { final Object error; … }
```

### 1.6 MVVM wiring

```
NoteListScreen (View)
   │ ListenableBuilder(listenable: viewModel)   ← rebuilds only when the state changes
   │ onTap(summary) → Navigator.push(NoteReplayScreen(noteId: summary.id))
   ▼
NoteListViewModel (ChangeNotifier)
   │ state: NoteListState
   │ query: String                → the current search text
   │ visibleNotes: List<NoteSummary> → filtered list, recomputed only when the query or notes change
   │ load()  → called once when the screen first opens; Retry calls it again
   │ search(String query) → updates query + visibleNotes, notifies once
   │ clearSearch()
   ▼
NoteRepository.listNotes() → Future<Result<List<NoteSummary>>>   (cached after the first call)
   ▼
NoteAssetService.listAssets() → Future<List<String>>   (every asset path in the manifest; the repository keeps assets/notes/*.csv)
```

| File (already created) | Responsibility for Home |
|---|---|
| `lib/data/services/note_asset_service.dart` | `listAssets()`: reads the asset manifest. Filtering to `assets/notes/*.csv` happens in the repository, so it can be unit-tested with a fake service. (`loadCsv(path)` will be used by the detail screen) |
| `lib/data/repositories/note_repository.dart` | `listNotes()`: builds `NoteSummary`s from the paths (title and natural sort), caches them, and returns a `Result` |
| `lib/domain/models/note_summary.dart` | The model in §1.3 |
| `lib/ui/note_list/view_models/note_list_view_model.dart` | Holds the state (§1.5), the search text and the filtered list, plus the `load()`, `search()` and `clearSearch()` commands. The filtering happens here, not in `build()`. Never touches `BuildContext` |
| `lib/ui/note_list/widgets/note_list_screen.dart` | AppBar with the search bar, the switch over states, rows, and navigation on tap. Owns the search field's `TextEditingController` (a View concern) and forwards each change to `viewModel.search()` |
| `lib/app/dependencies.dart` | Creates `NoteAssetService` → `NoteRepository` once |
| `lib/app/app.dart` | `MaterialApp(home: NoteListScreen(viewModel: NoteListViewModel(repository)))` |
| `lib/main.dart` | Replaces the counter app: `runApp(App(dependencies))` |

The ViewModel is created in `app.dart` and passed into the screen, so tests can give the
screen a ViewModel with a fake repository. The list screen stays mounted under the detail
screen, so going back shows the list immediately without reloading.

### 1.7 Accessibility

- Each `ListTile` is announced as its title, and as a button because it has `onTap`. No custom `Semantics` is needed.
- Rows are at least 48 dp tall (the `ListTile` default), so taps are easy to hit.
- Titles grow with the system text size. Nothing truncates them or limits the scaling.
- The AppBar title is announced as a heading by `AppBar` itself.
- The search field is announced as "Search notes" (from its hint), and the clear button as
  "Clear search" (its tooltip).
- When the number of matching notes changes, a screen-reader announcement says the new
  count (for example "2 notes"), so blind users know the list updated while they type.

### 1.8 Tests

| Level | File | Cases |
|---|---|---|
| Unit | `test/data/repositories/note_repository_test.dart` | Titles from file names. Natural sort (`note_10` after `note_9`). Non-CSV and non-`notes/` assets skipped. Second call served from cache. A service failure becomes `Result.error` |
| Unit | `test/ui/note_list/view_models/note_list_view_model_test.dart` | loading → data, loading → empty, loading → error, and retry → data. Listeners notified once per state change. Search: case doesn't matter ("NOTE 3"), spaces trimmed, "3" → 1 match, "note" → 5, "xyz" → 0, clearing shows all again |
| Widget | `test/ui/note_list/widgets/note_list_screen_test.dart` | AppBar shows "Notes" and the search bar. 5 rows with only "Note 1"…"Note 5". Tapping "Note 3" pushes the detail screen with id `note_3`. Empty and error states shown, with the search bar disabled. Retry calls `load()`. Typing "3" leaves one row. Typing "xyz" shows the no-match message, and its Clear search button restores all rows. ✕ appears only with text. The search is still there after going to a note and back |
| Widget | `test/widget_test.dart` | Replace the counter test with an app smoke test: the app starts on Home with the real asset bundle and shows 5 notes |

### 1.9 Implementation order

1. `NoteSummary` and `Result`
2. `NoteAssetService.listAssets()`, `NoteRepository.listNotes()`, and the repository tests
3. `NoteListViewModel` with search, and its tests
4. `NoteListScreen` with the search bar, plus an empty placeholder `NoteReplayScreen(noteId)` so navigation can be built and tested
5. `dependencies.dart`, `app.dart` and `main.dart`, replacing the counter app and its test
6. Widget tests and a manual check on a phone and a wide window
