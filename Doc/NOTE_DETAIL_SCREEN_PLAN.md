# Note Replay Animation — Note Detail Screen Plan

Status: Approved · Date: 2026-10-22 · Builds on [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) and [SCREENS_PLAN.md](SCREENS_PLAN.md)

This document turns the Note detail screen requirements into a plan that fits the approved
MVVM architecture and the rendering pipeline in the architecture plan (§4–§8). The screen
is implemented as `NoteReplayScreen`, which Home already opens when a note is tapped.

---

## 1. Requirements

| # | Requirement |
|---|---|
| D1 | App bar title: the **title of the selected note** |
| D2 | App bar action: **Settings**, which opens a bottom sheet "same as the prototype app" |
| D3 | Bottom sheet title: **"Canvas & Pen Settings"** |
| D4 | Bottom sheet: **ink colour** selection, maximum 5 colours |
| D5 | Bottom sheet: **paper background**, either **Blank** or **Dot grid** |
| D6 | Bottom sheet: a **Display & Coordinates** section with a **Show Pen Tip Indicator** switch |
| D7 | Body: a **canvas** that supports **static rendering** (the whole note at once) and **animated replay** |
| D8 | A **floating action button** to start the animation |
| D9 | **Blank** paper selected by default |
| D10 | At the bottom of the canvas: **total points**, **total strokes**, **canvas size**, and **pen writing** and **pen lift** times |
| D11 | Pen writing and pen lift show the **milliseconds from the current point to the next point** |

## 2. Open questions

The defaults in this table were approved with the plan. Each one can still change without affecting the
architecture.

| # | Question | Default in this plan |
|---|---|---|
| Q1 | **The prototype app hasn't been shared with me.** D2 says the sheet should look the same as it | The sheet is laid out from the text in D3–D6 (§5). Screenshots or a link would let me match the layout, spacing, controls and wording |
| Q2 | "Ink colours, max 5": a palette of 5 preset colours where the user picks one, or a user-built list of up to 5? | **5 preset colours, pick one** (§5.2) |
| Q3 | D8 gives a button to start the animation. Should it also pause, and is a progress bar wanted? | The floating button **starts, pauses, resumes and replays** (one button, icon changes with the state, §4.1). Under the canvas, a **progress bar and time label** let the user see and drag the position. Speed and pause shortening are supported by the engine but **not shown** in v1 |
| Q4 | What does the screen show when it opens? | **The complete note, static.** Nothing moves until the user taps the floating button (D8). This also suits the system's reduce-motion setting without special handling |
| Q5 | Are settings per note or for the whole app? Kept after a restart? | **For the whole app**, kept while the app runs, **not saved across restarts**. Saving can be added later without changing the screen (§6.1) |

---

## 3. Screen layout

```
┌──────────────────────────────────┐
│ ←  Note 3                     ⚙  │  AppBar(title: note.title, actions: [Settings])
├──────────────────────────────────┤
│ · · · · · · · · · · · · · · · ·  │
│ · · · · · · · · · · · · · · · ·  │
│ · · · ·  6 8 3 1   7 9 5 2 · · · │  ReplayCanvas: paper + ink + pen tip
│ · · · · · · · · · · · · · · · ·  │  (fills the space between the app bar and the playback bar)
│ · · · · · · · · · · · · · ┌────┐ │
│ Points 1,528  Strokes 8   │ ▶  │ │  NoteStatsPanel (bottom band)  +  FloatingActionButton
│ Canvas 390 × 612 px  …    └────┘ │
├──────────────────────────────────┤
│  ━━━━━━━━━━━━●──────  0:03 / 0:06 │  ReplayProgressBar + time label
└──────────────────────────────────┘
```

- **App bar:** back button, the note's title, and a Settings `IconButton` (`Icons.tune`,
  tooltip "Canvas & Pen Settings").
- **Canvas:** fills the body. The note is scaled to fit with 16 px of padding and centred
  ([ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) §5.3). Rotating the device or resizing the
  window refits it without restarting playback.
- **Floating action button** (D8): bottom-right (`FloatingActionButtonLocation.endFloat`),
  just above the playback bar. It starts the animation and changes to pause, play or replay
  as the state changes (§4.1).
- **Stats band (D10):** a band along the bottom of the canvas, on the paper, holds the
  note stats (§4.6) on the left and leaves room for the floating button on the right. The
  band is at least 72 dp tall (the button plus its margin), and the ink is fitted into the
  area above it, so neither the stats nor the button ever cover ink, even when large text
  makes the stats wrap.
- **Playback bar** (Q3): a draggable progress bar and `elapsed / total` time, in
  `Scaffold.bottomNavigationBar`. The time updates at most 10 times a second.

### 3.1 Getting the title (D1)

Home currently opens the screen with `NoteReplayScreen(noteId: note.id)`, so the title
isn't available until the CSV is parsed. The screen will take the whole `NoteSummary`
instead: `NoteReplayScreen(note: summary)`. The title then shows **immediately**, while
the CSV is still loading.

*As built:* the detail screen also needs the note and settings repositories, which Home
doesn't own. So `NoteListScreen` takes a `noteDetailBuilder` from `App`, which builds
`NoteReplayScreen(note: …, noteRepository: …, settingsRepository: …)`. Home stays unaware
of the replay feature, and its tests use a stand-in detail screen.

### 3.2 Screen states

| State | App bar | Body | Floating button | Playback bar |
|---|---|---|---|---|
| `loading` | Title + Settings (enabled) | Paper background with a centred spinner | Hidden | Hidden |
| `ready` | Title + Settings | Canvas (§4), complete note on open | Shown (Play) | Shown, at the end |
| `error` | Title + Settings | "Couldn't open this note." + **Retry** | Hidden | Hidden |

Settings stay usable in every state, because they don't depend on the note.

---

## 4. Canvas: static rendering and animated replay (D7)

Static rendering and replay use **one canvas and one pipeline**. Static rendering is
replay with the playback time `T` held at the end of the note. There is no separate static
painter, so the two modes can never look different.

| Mode | Playback time `T` | Ticker | What's drawn |
|---|---|---|---|
| **Replay (playing)** | Advances with the frame clock ([ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) §6) | Running | Finished strokes + the stroke being written + pen tip |
| **Paused** | Held where it stopped | Stopped | The note as written up to `T` + pen tip (if mid-stroke) |
| **Static** (on open, and after the replay completes) | Held at `duration` | Stopped | The whole note |

Switching between modes only changes `T` and starts or stops the ticker. When the ticker
is stopped, no frames are drawn, so a static note uses no CPU or GPU after its first frame.

### 4.1 Playback controls

The floating button (D8) is the only play control. Its icon and tooltip follow the
playback state:

| State | Button icon | Tooltip | Tap does |
|---|---|---|---|
| Static, just opened | ▶ `play_arrow` | "Play" | Set `T = 0` and play: the note disappears and is rewritten from the start |
| Playing | ⏸ `pause` | "Pause" | Stop at `T` |
| Paused | ▶ `play_arrow` | "Resume" | Play on from `T` |
| Static, replay completed | ↻ `replay` | "Replay" | Set `T = 0` and play |

| Other control | Action |
|---|---|
| Drag the progress bar | Seek to the dragged time. Playback pauses while dragging and resumes on release if it was playing. Dragging from static leaves it paused at that point, with the button showing "Resume" |

- The button shows one icon at a time with a matching tooltip, so its state isn't shown by
  colour alone. Screen readers read the tooltip as its label.
- It's a standard 56 dp `FloatingActionButton`, so it meets the 48 dp minimum touch size.
- The icon swaps instantly. No animated morph, so nothing moves for users with reduce-motion on.

### 4.2 Canvas layers

`ReplayCanvas` stacks three `CustomPaint` layers, each in its own `RepaintBoundary`:

| Layer (bottom → top) | Painter | Repaints when | Per-frame cost while playing |
|---|---|---|---|
| Paper | `PaperPainter` (new) | Canvas resized, or paper setting changed | **0** |
| Finished ink | `CommittedInkPainter` | A stroke finishes, after a seek, or ink colour changed | **0**, except the frame where a stroke finishes |
| Active ink + pen tip | `ActiveInkPainter` | Every frame while playing. Also on seek, pause, or a setting change | 1–3 `drawRawPoints` + 1 circle |

This adds the paper layer to the two ink layers in [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md)
§5.2. Everything else in the pipeline (clock, cursor, typed arrays, transform, rebuild
isolation) is unchanged.

### 4.3 Paper background (D5)

| Option | Drawing |
|---|---|
| **Blank** | Fills the canvas with the paper colour (warm white, `#FFFDF8`) |
| **Dot grid** | The paper colour plus dots every **24 logical pixels**, fixed on screen and centred on the canvas, so **every note gets the same grid** whatever its size. Dot radius 1 px, colour `#C9C4BA` |

*Changed after review:* the grid was first spaced every 5 mm in note space, so it scaled
with each note. Short notes are zoomed in to fit the screen and got sparse dots; long notes
are zoomed out and got dense ones. A fixed on-screen spacing keeps the paper consistent.
The grid no longer lines up with the ink's millimetres, which nothing depends on.

- The dot positions are computed **once per canvas size or setting change** into one
  `Float32List` and drawn with a single `drawRawPoints(PointMode.points, …)`. Nothing is
  computed per frame.
- The grid covers the whole canvas, including the padding around the note.
- The app is now light-only (`darkTheme` uses the light theme), so the paper and ink
  colours are chosen for a light background.

### 4.4 Ink colour (D4)

- The ink colour is a constructor value of both ink painters. Changing it rebuilds
  `ReplayCanvas` once with new painter settings, and `shouldRepaint` repaints both ink
  layers once. The new colour applies to the whole note, including what was already drawn.
- All ink colours are **fully opaque**, as the architecture plan requires (§5.4).
- `Paint` objects are created once per colour in `InkStyle`, never inside `paint()`.

### 4.5 Pen tip indicator (D6)

- **On:** a filled circle at the current pen position, in the ink colour, with a radius of
  1.5× the line width and a 1 px paper-coloured outline so it stays visible over ink.
- It's drawn in the active layer, at the exact interpolated position for `T`
  ([ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) §6.2), so it adds no extra layer or repaint.
- It's shown **only while the pen is down**: while playing or paused mid-stroke. It's
  hidden during pauses between strokes and in static mode, where there's no current pen
  position to show.
- **Off:** not drawn. Turning it on or off repaints the active layer once.

### 4.6 Note stats (D10)

`NoteStatsPanel` shows, left to right and wrapping onto more lines as needed:

| Label | Value | Source |
|---|---|---|
| Points | `1,478` | `Note.pointCount` |
| Strokes | `13` | `Note.strokeCount` |
| Canvas | `390 × 612 px` | The whole canvas's size in logical pixels, from its `LayoutBuilder` |
| Pen writing | `2.43 ms` | While the pen is down: time from the current point to the next point in the stroke (D11) |
| Pen lift | `140.00 ms` | While the pen is up between strokes: time from the previous stroke's last point to the next stroke's first point (D11) |

- Pen writing shows `—` while the pen is up, and pen lift shows `—` while the pen is down.
  Both show `—` on the complete note, which has no current point.
- The cursor already finds the current point each frame, so it writes both intervals into
  the frame snapshot at no extra cost. The ViewModel publishes them as microseconds in two
  `ValueNotifier`s, which fire only when the value changes. So the two text items rebuild
  when a stroke starts or ends, or when the CSV's rounding changes the gap (2.43 ↔ 2.44 ms).
  They never rebuild on every frame. The rest of the panel rebuilds only when the note
  loads or the canvas resizes.
- *Replaced:* these two items first showed whole-note totals in seconds (3.56 s writing,
  2.51 s lift for note_1).
- Each item is a label in the muted text colour followed by its value in bold, read by
  screen readers as one phrase ("Points 1,478").

---

## 5. Settings bottom sheet (D2–D6)

Opened with `showModalBottomSheet(showDragHandle: true, isScrollControlled: true)`. The
sheet sizes itself to its content and leaves the canvas visible above it. **Changes apply
immediately**, there's no Save button, and **playback keeps running**, so the user sees the
effect while choosing. Swiping down or tapping outside closes the sheet.

```
┌──────────────────────────────────┐
│               ────               │  drag handle
│  Canvas & Pen Settings           │  title (titleLarge)
│                                  │
│  Ink colour                      │  section label (titleSmall)
│  (✓●)  (●)  (●)  (●)  (●)        │  5 swatches, check mark on the selected one
│                                  │
│  Paper background                │
│  [ ▢ Blank  |  ⁘ Dot grid ]      │  SegmentedButton<PaperBackground>
│                                  │
│  Display & Coordinates           │
│  Show Pen Tip Indicator    [●━]  │  SwitchListTile
└──────────────────────────────────┘
```

This layout comes from the requirements text. It will be adjusted to match the prototype
once it's shared (Q1).

### 5.1 Sections

| Section | Control | Options | Default |
|---|---|---|---|
| Ink colour | 5 round swatches, single choice | See §5.2 | Black |
| Paper background | `SegmentedButton`, single choice | Blank, Dot grid | **Blank** (D9) |
| Display & Coordinates | `SwitchListTile` | Show Pen Tip Indicator | On |

### 5.2 Ink colours

| Name | Colour | Contrast on `#FFFDF8` paper |
|---|---|---|
| Black (default) | `#1A1A1A` | 17:1 |
| Blue | `#1E5BD8` | 5.8:1 |
| Red | `#C62828` | 5.5:1 |
| Green | `#2E7D32` | 5.0:1 |
| Purple | `#6A1B9A` | 9.2:1 |

All five pass the 3:1 contrast that WCAG requires for graphics, so ink stays readable on
both paper options. The grid dots are deliberately faint (1.7:1), because they're
decoration and must not compete with the ink.

### 5.3 Accessibility

- **Swatches:** 48 × 48 dp touch targets, announced as "Ink colour, Blue", plus "selected"
  for the current one. The selected swatch shows a **check mark**, so the choice isn't
  shown by colour alone.
- `SegmentedButton` and `SwitchListTile` provide their own labels and selected/on states.
- The section labels are headings for screen readers.
- The sheet scrolls if large text makes it taller than the screen.

---

## 6. MVVM wiring

```
NoteListScreen ──push──▶ NoteReplayScreen(note: NoteSummary)
                              │ owns: NoteReplayViewModel (created in initState with
                              │       TickerFrameClock(this), disposed in dispose)
                              ▼
NoteReplayViewModel
   │ loadState: ValueListenable<NoteLoadState>   loading | ready(note) | error
   │ status:    ValueListenable<PlaybackStatus>  ready | playing | paused | completed
   │                                             ─▶ floating button (rebuilds only on change)
   │ frame:     ReplayFrame (Listenable, every vsync)      ─▶ ActiveInkPainter, progress bar
   │ committedStrokes: ValueListenable<int>                ─▶ CommittedInkPainter
   │ clockLabel: ValueListenable<int> (tenths of a second) ─▶ time Text
   │ settings:  ValueListenable<CanvasSettings> (from CanvasSettingsRepository)
   │ commands: load(), togglePlayback(), seek(t), setInkColor(c),
   │           setPaper(p), setShowPenTip(b)
   ▼
NoteRepository.loadNote(id)          CanvasSettingsRepository (in memory, app-wide)
```

The per-frame path is unchanged from [ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) §7. Settings
changes are rare events. They rebuild only `ReplayCanvas` (to give its painters new values)
and the sheet, never on a per-frame basis.

### 6.1 Settings model and storage

```dart
enum InkColor { black, blue, red, green, purple }
enum PaperBackground { blank, dotGrid }

final class CanvasSettings {
  const CanvasSettings({
    this.inkColor = InkColor.black,
    this.paper = PaperBackground.blank,
    this.showPenTip = true,
  });
  final InkColor inkColor;
  final PaperBackground paper;
  final bool showPenTip;
  CanvasSettings copyWith({InkColor? inkColor, PaperBackground? paper, bool? showPenTip});
}
```

- The domain uses enums, not `Color`. `InkStyle` in the UI layer maps each `InkColor` to its
  colour, so the domain layer stays free of `dart:ui`.
- `CanvasSettingsRepository` holds the current settings in a `ValueNotifier`. It's created
  once in `Dependencies`, so the settings are shared by every note for the app's lifetime
  (Q5). Saving across restarts later means swapping in a stored version of this repository.
  Nothing else changes.

### 6.2 Files

New files are marked **new**. All other files already exist as placeholders.

| File | Responsibility |
|---|---|
| `lib/domain/models/canvas_settings.dart` **new** | `CanvasSettings`, `InkColor`, `PaperBackground` |
| `lib/data/repositories/canvas_settings_repository.dart` **new** | In-memory settings with a `ValueListenable` |
| `lib/app/dependencies.dart` | Adds `CanvasSettingsRepository` |
| `lib/ui/core/ink_style.dart` | `InkColor` → colour and name, `Paint` objects, line width (0.45 mm), paper and dot colours |
| `lib/ui/replay/view_models/frame_clock.dart` | `FrameClock` and `TickerFrameClock` |
| `lib/ui/replay/view_models/replay_timeline.dart` | Playback time from the clock, with speed (1× in v1) |
| `lib/ui/replay/view_models/replay_cursor.dart` | Forward-only cursor and binary-search seek |
| `lib/ui/replay/view_models/replay_frame.dart` | The per-frame snapshot the painters read |
| `lib/ui/replay/view_models/note_geometry.dart` **new (added while building)** | The note plus one point view per stroke, built once on load ([ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) §4) |
| `lib/ui/replay/view_models/note_replay_view_model.dart` | Loading, playback state and commands, settings commands |
| `lib/ui/replay/widgets/note_replay_screen.dart` | App bar, states, opens the sheet, owns the ViewModel |
| `lib/ui/replay/widgets/replay_canvas.dart` | The three-layer stack and the cached fit-to-canvas transform |
| `lib/ui/replay/widgets/paper_painter.dart` **new** | Blank or dot-grid paper |
| `lib/ui/replay/widgets/note_stats_panel.dart` **new** | The stats at the bottom of the canvas (§4.6) |
| `lib/ui/replay/widgets/committed_ink_painter.dart` | Finished strokes |
| `lib/ui/replay/widgets/active_ink_painter.dart` | Current stroke and pen tip |
| `lib/ui/replay/widgets/playback_controls.dart` | The floating Play/Pause/Resume/Replay button (§4.1) |
| `lib/ui/replay/widgets/replay_progress_bar.dart` | Painted, draggable progress bar and the time label |
| `lib/ui/replay/widgets/canvas_settings_sheet.dart` **new** | The bottom sheet and `showCanvasSettingsSheet()` |
| `lib/ui/note_list/widgets/note_list_screen.dart` | Opens the detail screen through `noteDetailBuilder`, passing the `NoteSummary` (§3.1) |

---

## 7. Tests

| Level | File | Cases |
|---|---|---|
| Unit | `replay_cursor_test.dart` | Forward advance matches a brute-force search at random times. Seek forwards and backwards. Stroke boundaries. Pen tip interpolated exactly between samples. Stroke count at `T = duration` equals all strokes |
| Unit | `replay_timeline_test.dart` | Time comes from the clock without drift. Re-anchors on play and seek. Clamped to `[0, duration]` |
| Unit | `canvas_settings_repository_test.dart` | Defaults. Each setter updates the value and notifies once. Setting the same value doesn't notify |
| Unit | `note_replay_view_model_test.dart` | With a manual frame clock: load → static, ticker stopped. `togglePlayback` from static → playing from `T = 0`, then paused → resumed → completed (static). Seek while playing and from static. Load error → Retry |
| Widget | `note_replay_screen_test.dart` | App bar shows the note's title while loading. Opens on the complete note. The floating button is hidden while loading and on error. Its icon and tooltip go Play → Pause → Resume → Replay. The Settings button opens the sheet. Error and Retry. **0 rebuilds** of the screen, app bar, button and playback bar across 100 frames of playback |
| Widget | `canvas_settings_sheet_test.dart` | Title "Canvas & Pen Settings". 5 swatches with labels and the check on the selected one. Choosing a colour, paper option or switch updates the settings. The sheet closes on swipe |
| Golden | `replay_canvas_golden_test.dart` | note_1 static on Blank and Dot grid. Mid-stroke with the pen tip on and off. Each ink colour. Deterministic because a frame depends only on `T`. *Not written yet: reference images can only be generated by running `flutter test --update-goldens`* |
| Widget | `note_list_screen_test.dart` (update) | Tapping "Note 3" opens the detail screen with `note.id == 'note_3'` and title "Note 3" |

---

## 8. Implementation order

1. **Settings:** `CanvasSettings`, `CanvasSettingsRepository`, `Dependencies`, plus tests
2. **Playback engine (pure Dart):** `FrameClock`, `ReplayTimeline`, `ReplayCursor`, `ReplayFrame`, plus tests
3. **ViewModel:** `NoteReplayViewModel`, plus tests
4. **Canvas:** `InkStyle`, `PaperPainter`, the two ink painters, `ReplayCanvas`, plus golden tests
5. **Screen:** `NoteReplayScreen` with app bar, states, floating button and playback bar. Home passes the `NoteSummary`
6. **Settings sheet:** `canvas_settings_sheet.dart`, plus tests. Match it to the prototype once shared (Q1)
7. **Checks:** the rebuild-isolation test, then profile mode on a 120 Hz device ([ARCHITECTURE_PLAN.md](ARCHITECTURE_PLAN.md) §8)
