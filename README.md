# Note Replay Animation

A Flutter app that replays handwritten notes stroke by stroke, at the speed they were
written. Each note is a pen recording: X/Y positions, timestamps and stroke numbers. The
app draws them with Flutter's own `CustomPaint`, `CustomPainter` and `Canvas` at
60–120 fps, with no rendering packages.

You can also write a new note with your finger or a stylus. The app saves it and then
animates your writing back to you.

## Features

**Home (Notes)**
- Lists the 5 bundled notes and any notes you've written, by title.
- Search by title.
- A **+** button opens a blank canvas for a new note.

**Note detail (replay)**
- Shows the whole note when it opens. **Play** animates it from the start, with **Pause**,
  **Resume** and **Replay**.
- A progress bar shows elapsed and total time, and you can drag it to seek.
- **Canvas & Pen Settings** (tune icon):
  - Ink colour: Black, Blue, Red, Green or Purple
  - Paper: Blank (default) or Dot grid. The grid has the same spacing on every note
  - Show Pen Tip Indicator
- A stats bar under the canvas shows:
  - total points and strokes
  - canvas size
  - live **Pen writing** and **Pen lift** times, in ms from the current point to the next

**New note**
- Write anywhere on the canvas, with **Undo** and **Clear**.
- **Animate** saves the note, then opens it and plays it straight away.
- Leaving with unsaved writing asks "Discard this note?" first.
- Saved notes are listed as "New note 1", "New note 2"… and are still there after a
  restart. On the web they last only until the tab closes.

## Getting started

Needs Flutter 3.44 (Dart 3.12) or later.

```sh
flutter pub get
flutter run            # pick a device: iOS, Android, macOS, Windows, Linux or Chrome
```

Common commands:

```sh
flutter analyze        # static analysis
flutter test           # unit and widget tests
flutter run --profile  # use profile mode to measure frame rate
```

## Data format

The bundled notes are in `assets/notes/note_1.csv` … `note_5.csv` (about 11,300 points in
all). They were exported from a smart pen:

```
x,y,t,stroke
-7.1898e-05,-8.01011e-05,0.977954,0
-7.51379e-05,-0.000113614,0.980387,0
```

| Column | Meaning |
|---|---|
| `x`, `y` | Pen-tip position in **metres**. The y-axis points down, like the canvas |
| `t` | Time in **seconds**. The pen samples at about **411 Hz**, one point every 2.43 ms |
| `stroke` | Stroke number. A new number means the pen lifted and went down again |

When a note loads, the parser:
- converts metres to millimetres
- moves the note's top-left corner to (0, 0)
- starts time at 0
- rejects bad files with a clear error, such as a missing column, a bad number, or time or
  stroke numbers going backwards

Notes you write are saved in the same format, at full precision, so both kinds load the
same way.

## Architecture

The app uses **MVVM** with no state-management packages. ViewModels are `ChangeNotifier`s
and `ValueNotifier`s, dependencies are passed in through constructors, and errors come back
as a `Result` (`Ok` or `Error`).

```
lib/
├── main.dart
├── app/                  App widget and dependency wiring (Dependencies)
├── domain/models/        Note (typed arrays), NoteSummary, CanvasSettings, InkRecording
├── data/
│   ├── parsers/          NoteCsvParser, NoteCsvWriter
│   ├── services/         NoteAssetService, DrawnNoteStore (file and in-memory versions)
│   └── repositories/     NoteRepository, CanvasSettingsRepository
├── ui/
│   ├── core/             Theme and ink style (colours, cached Paints)
│   ├── note_list/        Home: view model and screen
│   ├── replay/           Note detail: clock, cursor, view model, painters, settings sheet
│   └── draw/             New note: view model, recording painters and screen
└── utils/result.dart
```

The data flows like this:

```
CSV asset / saved file ──▶ NoteRepository ──▶ NoteReplayViewModel ──▶ ReplayCanvas
                         (parse in background,   (clock + cursor        (CustomPaint layers)
                          cache the Note)         → ReplayFrame)
```

### How the replay stays smooth

- **Data in flat typed arrays.** A note is stored as a few typed lists:
  - `Float32List` for positions (in mm)
  - `Float64List` for times
  - `Int32List` for where each stroke starts

  Parsing runs in a background isolate with `compute`, so it doesn't freeze the UI.
- **Exact timing.** A `Ticker` drives playback once per screen refresh, so 60, 90 and
  120 Hz displays all play at the right speed.
  - Playback time is worked out from the frame's timestamp each time, not added up frame by
    frame, so it never drifts.
  - The pen tip is placed exactly between two samples, so movement is smooth even though
    the pen sampled at 411 Hz.
- **Little work per frame.** A cursor only moves forward through the points. Each frame
  draws only the points added since the last frame, and seeking back uses a binary search.
  - No objects are created during a frame.
  - No paths are rebuilt during a frame.
  - The whole note is never scanned during a frame.
- **Only the canvas repaints.** The canvas has three layers, each in its own
  `RepaintBoundary`:
  - **paper:** repaints when the paper setting changes
  - **finished strokes:** repaints when a stroke is completed
  - **current stroke and pen tip:** repaints every frame

  Painters repaint through `CustomPaint(repaint: …)`, so the page and its other widgets
  don't rebuild on each frame. The progress bar and stats have their own small notifiers,
  which change only when their value does.
- **Fast drawing call.** Ink is drawn with `Canvas.drawRawPoints` and round caps. The note
  is scaled to fit the canvas by one canvas transform, rather than by converting each
  point.

The full design is in [`Doc/`](Doc):

| Document | Covers |
|---|---|
| [ARCHITECTURE_PLAN.md](Doc/ARCHITECTURE_PLAN.md) | Layers, rendering pipeline, timing, performance rules |
| [SCREENS_PLAN.md](Doc/SCREENS_PLAN.md) | Home screen and search |
| [NOTE_DETAIL_SCREEN_PLAN.md](Doc/NOTE_DETAIL_SCREEN_PLAN.md) | Replay screen, settings sheet, dot grid, stats |
| [NEW_NOTE_PLAN.md](Doc/NEW_NOTE_PLAN.md) | Writing a new note, and saving it |

## Saving notes you write

- **Where:** each note is saved as `<app documents>/drawn_notes/drawn_N.csv`, using
  `path_provider` to find the folder.
- **Safe writes:** the note goes to a `.tmp` file first, which is then renamed into place,
  so a crash can't leave a half-written note.
- **If saving fails:** your writing stays on the canvas and a message asks you to try again.
- **Numbering:** new notes continue from the highest saved number, so numbers are never
  reused.

## Tests

The tests are in `test/`, laid out like `lib/`. They cover:
- **Parsing:** the CSV parser and writer, including a round trip through both.
- **Saving:** the file store, using a temporary folder.
- **Repository:** including a simulated restart.
- **Replay:** the cursor, the timeline and every view model.
- **Screens:** widget tests for each screen. One test checks that the page doesn't rebuild
  during playback.

Helpers in `test/helpers/`:
- `ManualFrameClock` steps playback frame by frame, so timing tests are exact.
- `FakeNoteRepository` and `FakeNoteAssetService` stand in for the real data sources.

## Limitations

- You can't delete or rename notes you've written yet. They're always "New note N".
- On the web, notes you write aren't saved after the tab closes.
- Pen pressure and tilt aren't used. The CSV data doesn't have them.
- There are no golden image tests yet, and frame rate hasn't been measured on a 120 Hz
  device.
