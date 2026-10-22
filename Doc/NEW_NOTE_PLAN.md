# Note Replay Animation — New Note Plan

Status: Built, with saving (tests not yet run) · Date: 2026-10-22 · Builds on [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md), [SCREENS_PLAN.md](SCREENS_PLAN.md) and [NOTE_DETAIL_SCREEN_PLAN.md](NOTE_DETAIL_SCREEN_PLAN.md)

Records the design of writing a new note in the app and replaying it. It was built
straight from the request, so the defaults in §2 were chosen during implementation.

---

## 1. Requirements

| # | Requirement |
|---|---|
| N1 | A floating **Add** button on the Home screen |
| N2 | It opens a **fresh canvas** where the user can write anything |
| N3 | Afterwards, the writing is **animated** |
| N4 | Drawn notes are **saved** and still listed after the app restarts |

## 2. Defaults chosen

| Question | Default | Why |
|---|---|---|
| How does the user finish? | An **Animate** button (play icon), shown once a stroke is finished | It says what happens next. Hidden while empty, so it can't make an empty note |
| What happens to the note? | **Saved** (N4) and added to the Home list as **"New note N"** | "Add" suggests a new list entry |
| Does the replay start on its own? | **Yes**, for a new note | The request asks for the writing to animate afterwards. Notes opened from the list still open static (Q4 in the detail plan) |
| Editing while writing | **Undo** (last stroke) and **Clear** in the app bar | Basic recovery from mistakes |
| Leaving with ink | Asks "Discard this note?" first | Avoids losing writing by accident |
| Several fingers | Only the first pointer draws until it lifts | A resting palm or second finger doesn't add strokes |
| Paper and ink colour | The current canvas settings | Writing looks the same as its replay |

## 3. Flow

```
Home ──(+ New note)──▶ New note screen ──(Animate)──▶ Replay screen (autoPlay)
  ▲                         │ Back: leaves, or asks if there's ink      │
  └──── refresh() ◀─────────┴──────────────── Back ─────────────────────┘
```

- **Animate** calls `NoteRepository.addDrawnNote` and **replaces** the New note screen with
  the replay screen, so Back from the replay returns to Home.
- When the pushed route completes, Home calls `NoteListViewModel.refresh()`. It re-reads
  the list **without the loading state**, so the new note appears without a spinner flash
  and the search is kept.

## 4. Recording

| Piece | Responsibility |
|---|---|
| `InkRecording` (domain) | Growable typed buffers per stroke (sizes double as they fill: no per-point objects), finished strokes, undo, clear, and `toNote(id)` |
| `DrawNoteViewModel` (UI) | Turns pointer events into recording calls, tracks the drawing pointer, exposes `strokeCount`, `hasInk` and `activeStroke` |
| `RecordedInkPainter` / `LiveInkPainter` | Finished strokes (repaint when a stroke ends, on undo, on clear) and the stroke being written (repaint per new point) |
| `DrawNoteScreen` | `Listener` for raw pointer events, the three paint layers, hint, Undo, Clear, Animate, discard prompt |

- **Units:** positions are converted from logical pixels to **millimetres** at
  1/160 inch per logical pixel (25.4 / 160 mm), and timestamps from
  `PointerEvent.timeStamp` to seconds. A drawn note is then a normal `Note`, so the
  replay engine, settings and stats work unchanged.
- **Timing is real:** the replay follows the device's touch sampling (typically 60–240 Hz),
  so Pen writing shows that interval (for example 8.33 ms at 120 Hz) rather than the
  pen's 2.43 ms.
- **Time never goes backwards:** a timestamp earlier than the last one is clamped to it,
  which the replay cursor relies on.
- `toNote` moves the ink's top-left to (0, 0) and the first sample to time 0, like the
  CSV parser.
- **No rebuilds while writing:** pointer moves fire only `activeStroke`, which repaints the
  live-ink layer. The hint, buttons and app bar rebuild only when `hasInk` or
  `strokeCount` changes.

## 5. Saving (N4)

| Piece | Responsibility |
|---|---|
| `DrawnNoteStore` (data/services) | Interface: `listIds`, `read`, `write`, CSV text keyed by note id |
| `FileDrawnNoteStore` | `<documents>/drawn_notes/<id>.csv`, found with `path_provider`. Writes go to a `.tmp` file that's then renamed over the real one, so a crash mid-write never leaves a half-written note |
| `InMemoryDrawnNoteStore` | Used on the **web** (no file system, so notes last only until the tab closes) and as the repository's default in tests |
| `NoteCsvWriter` (data/parsers) | Writes a `Note` in the same `x,y,t,stroke` format as the pen export (metres, seconds), so saved notes load through `NoteCsvParser` like bundled ones. Numbers are written at **full precision**, avoiding the pen export's 6-significant-digit rounding |

- **When:** Animate saves the note **before** opening the replay. If saving fails, the
  writing stays on the canvas, a snackbar says "Couldn't save the note. Try again.", and
  nothing is added to the list. Animate is disabled while saving, so a double tap saves once.
- **Restart:** the first `listNotes` reads the store's ids, keeps those named `drawn_<N>`,
  sorts them by N and titles them "New note N". New notes continue from the highest saved
  N, so numbers are never reused.
- **Loading:** a saved note's CSV is read and parsed on first open, in the background like
  a bundled one, then cached.
- `Dependencies` uses `FileDrawnNoteStore` on every platform except the web.

## 6. Changes to existing code

| File | Change |
|---|---|
| `NoteSummary` | `assetPath` is now optional; drawn notes have none |
| `NoteRepository` | Keeps bundled and drawn summaries separately. `listNotes` returns bundled (natural order) then drawn (by number). `addDrawnNote` is async: it saves through `DrawnNoteStore`, then caches the `Note`, and returns a `Result`. Takes an optional `drawnNoteStore` (default: in memory) |
| `NoteListViewModel` | `refresh()`: re-reads without showing loading |
| `NoteListScreen` | Floating **+** button (tooltip "New note"), shown in every state. 88 dp of space under the list so the button never covers the last note. Takes a `newNoteBuilder` from `App` |
| `NoteReplayViewModel` / `NoteReplayScreen` | `autoPlay`: start playing as soon as the note loads |
| `ViewportTransform.fit` | Zoom capped at **20 px/mm**, so a tiny drawing (one word, a dot) isn't blown up to fill the canvas. Bundled notes fit below this cap on phones and tablets |

## 7. Tests

| File | Cases |
|---|---|
| `test/domain/models/ink_recording_test.dart` | Active vs finished strokes, buffer growth past 1,000 points, undo order, clear, `toNote` normalisation and stroke table, clamped time, single tap, stroke in progress left out, empty throws |
| `test/ui/draw/view_models/draw_note_view_model_test.dart` | Pixel → mm, pen down/move/up signals, second pointer ignored, undo/clear, `finish` adds a note with real timing |
| `test/ui/draw/widgets/draw_note_screen_test.dart` | Hint and disabled buttons when empty, writing shows Animate/Undo/Clear, undo to empty, Animate replaces the screen and Back goes Home, Back when empty, discard prompt |
| `note_repository_test.dart` (added) | Drawn notes listed after bundled ones and numbered, and loaded without reading an asset |
| `note_list_view_model_test.dart` (added) | `refresh` shows a new note without a loading state |
| `note_list_screen_test.dart` (added) | The + button opens the New note screen, a note added there is listed on return without a spinner, and the button shows in the error state |
| Replay tests (added) | `autoPlay` starts playing, in the ViewModel and on the screen |
| `test/data/parsers/note_csv_writer_test.dart` | Exact output format, round trip of note_1 through writer and parser, full time precision kept |
| `test/data/services/file_drawn_note_store_test.dart` | Real files in a temporary folder: folder created, write/read, a new store finds earlier notes, overwrite leaves no `.tmp`, non-CSV files ignored, missing note throws |
| `note_repository_test.dart` (saving) | Saved to the store, a **new repository on the same store lists and loads them** (a restart), numbering continues from the highest, unrelated files ignored, a failed save adds nothing |
| `draw_note_screen_test.dart` (saving) | A failed save keeps the writing and shows the snackbar |

## 8. Not done

- **Deleting** or **renaming** a drawn note: titles are "New note N".
- **Saving on the web:** notes there last only until the tab closes.
- **Pressure or tilt:** recorded by many styluses, but not used, to match the CSV data.
