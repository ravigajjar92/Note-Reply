# Note Replay Animation — Architecture Plan

Status: Approved · Date: 2026-10-21 · Flutter 3.44 / Dart 3.12

The app replays handwritten notes, captured with a NuwaPen and exported as CSV, by drawing
them on a canvas at the speed they were written. This document explains the app's
architecture, how it renders, and the performance rules it has to follow. It also covers
the input data and lists the implementation steps.

---

## 1. Goals and requirements

| # | Requirement | How this plan meets it |
|---|---|---|
| R1 | MVVM architecture | Data → Repository → ViewModel → View layers ([§3](#3-architecture-mvvm)) |
| R2 | Smooth 60–120 fps, matched to the display | A vsync-driven `Ticker` with a small fixed amount of work per frame ([§5](#5-rendering-pipeline), [§8](#8-high-refresh-rate-60120-hz)) |
| R3 | Built-in `CustomPaint` / `CustomPainter` / `Canvas` only | No rendering packages. All ink is drawn with `Canvas.drawRawPoints` ([§5.4](#54-drawing-primitive)) |
| R4 | Smooth animation with exact timestamps | Playback time comes from the frame timestamp, not added-up deltas. The pen tip is placed at sub-sample precision ([§6](#6-timestamp-accuracy)) |
| R5 | Only the canvas repaints during playback | Per-frame signals go straight to `RenderCustomPaint.markNeedsPaint`. There is no `setState` and no per-frame `notifyListeners` on the page's ViewModel ([§7](#7-rebuild-and-repaint-isolation)) |
| R6 | No per-frame allocations, transforms, path rebuilds or full scans | Typed arrays, a cursor that only moves forward, and geometry prepared once ([§5.5](#55-per-frame-budget-and-what-is-never-done-per-frame)) |

Not in scope for v1: editing ink, recording live pen input, cloud sync, and video export.
The design still allows video export later, because any frame can be produced from a time `T`.

---

## 2. Input data

Source: `notes/*.csv`. These are copied into the app as `assets/notes/note_{1..5}.csv`.

```
x,y,t,stroke
-7.1898e-05,-8.01011e-05,0.977954,0
```

| Column | Meaning | Notes |
|---|---|---|
| `x`, `y` | Pen-tip position in **metres**, relative to where the note started | The y-axis already points down, like Flutter's canvas, so no flip is needed |
| `t` | Seconds since the pen started recording | The first sample is at about 0.97 s, so subtract it at load time |
| `stroke` | Stroke index | 0..S-1, contiguous and in time order |

What the analysis of the 5 sample notes showed:

| Property | Value | Effect on the design |
|---|---|---|
| Sample rate | Exactly 2.43 ms (about 412 Hz), no dropouts | About 7 samples per frame at 60 Hz and about 3.4 at 120 Hz. The ink is dense enough to draw as a polyline |
| Size | 1.5k–3.8k points and 8–24 strokes per note | Fits easily in memory. Typed arrays keep the GC quiet |
| Pen speed | Median about 22 mm/s, top about 110 mm/s | Consecutive points are about 0.05 mm apart, so no curve fitting is needed |
| Pen-up pauses | 0.08–2.07 s, 30–40% of total time | Optional pause shortening ([§6.4](#64-pause-shortening-and-speed)) |
| Dot strokes | 0.6–1.5 mm ("i", ":", "!") | Round line caps are required |
| Pressure | Not recorded | Fixed line width in v1 |
| Orientation | note_3 is written at about 50° | Drawn as recorded. Straightening it is optional later |
| Time order | Strictly increasing, strokes never overlap in time | Binary search and a forward-only cursor are both valid |

---

## 3. Architecture (MVVM)

This follows Flutter's official app-architecture guidance (UI layer = View + ViewModel,
data layer = Repository + Service). It needs **no third-party packages**: ViewModels are
plain `ChangeNotifier` / `ValueNotifier` objects, Views listen with `ListenableBuilder` /
`ValueListenableBuilder`, and dependencies are passed in through constructors.

```
┌──────────────────────────────── UI layer ─────────────────────────────────┐
│  View (widgets)                         ViewModel                         │
│  NoteListScreen ─────────────────────▶  NoteListViewModel                 │
│  NoteReplayScreen                       NoteReplayViewModel               │
│   ├─ PlaybackControls  ◀── status ───┐   ├─ status   (ValueListenable)    │
│   ├─ ReplayProgressBar ◀── frame ────┤   ├─ frame    (Listenable, vsync)  │
│   └─ ReplayCanvas                    │   ├─ committedStrokes (ValueNotif.)│
│       ├─ CommittedInkPainter ◀───────┤   ├─ ReplayCursor                  │
│       └─ ActiveInkPainter  ◀─────────┘   └─ FrameClock (Ticker wrapper)   │
└───────────────────────────────────────────┬───────────────────────────────┘
                                            │ Future<Result<Note>>
┌──────────────────────────────── Data layer ───────────────▼───────────────┐
│  NoteRepository  (caches parsed notes, lists available notes)             │
│    └─ NoteAssetService (rootBundle.loadString)                            │
│    └─ NoteCsvParser    (runs via compute → typed arrays)                  │
└───────────────────────────────────────────────────────────────────────────┘
                                            │
                     Domain model: Note (immutable, typed arrays)
```

### 3.1 What each layer does

| Layer | Class | Responsibility | Must not |
|---|---|---|---|
| Service | `NoteAssetService` | Reads raw CSV text from the asset bundle | Parse or cache |
| Parser | `NoteCsvParser` | CSV text → `Note`. Converts m → mm, shifts time to 0 and the top-left corner to the origin, builds the stroke table | Use `dart:ui` |
| Repository | `NoteRepository` | Lists notes, loads and caches each `Note` once, returns `Result<T>` | Know about playback |
| ViewModel | `NoteListViewModel` | Loads the note list and exposes loading/error/data state | Hold widgets or `BuildContext` |
| ViewModel | `NoteReplayViewModel` | Owns playback state, the clock, the cursor and pause shortening, and exposes play/pause/seek/speed commands | Call `notifyListeners()` on every frame ([§7](#7-rebuild-and-repaint-isolation)) |
| View | `NoteReplayScreen` | Lays out the screen and connects listenables to widgets. Builds **once** per route | Contain playback logic |
| View | `ActiveInkPainter`, `CommittedInkPainter` | Draw from data that is already prepared | Allocate, transform points on the CPU, or search |

### 3.2 Folder structure

```
lib/
  main.dart                         # runApp + composition root
  app/
    app.dart                        # MaterialApp, routes, theme
    dependencies.dart               # builds services/repositories (constructor DI)
  data/
    services/note_asset_service.dart
    parsers/note_csv_parser.dart
    repositories/note_repository.dart
  domain/
    models/note.dart                # Note + StrokeTable (typed arrays)
    models/note_summary.dart        # id, title, asset path (list screen; see SCREENS_PLAN.md §1.3)
  ui/
    core/theme.dart, ink_style.dart
    note_list/
      view_models/note_list_view_model.dart
      widgets/note_list_screen.dart
    replay/
      view_models/note_replay_view_model.dart
      view_models/frame_clock.dart        # abstract FrameClock + TickerFrameClock
      view_models/replay_cursor.dart      # forward-only cursor + seek (pure Dart)
      view_models/replay_frame.dart       # mutable per-frame snapshot the painters read
      view_models/replay_timeline.dart    # recorded time ↔ replay time (pause shortening)
      widgets/note_replay_screen.dart
      widgets/replay_canvas.dart
      widgets/committed_ink_painter.dart
      widgets/active_ink_painter.dart
      widgets/replay_progress_bar.dart
      widgets/playback_controls.dart
  utils/
    result.dart                     # sealed Result<T> = Ok | Error
assets/notes/note_1.csv … note_5.csv
test/ …                             # mirrors lib/ (see §10)
```

---

## 4. Domain model: built for rendering speed

The `Note` stores its data as **typed arrays** (struct-of-arrays), not as a `List<InkPoint>`.
That means one allocation per array, not one object per point, data the GC barely has to
look at, and arrays that can be **handed straight to `Canvas.drawRawPoints`** without copying.

```dart
/// An immutable handwritten note. All coordinates are in millimetres, with the
/// top-left of the ink bounds at (0, 0). Times are seconds from the first sample.
final class Note {
  final String id;
  final Float32List xy;          // interleaved x0,y0,x1,y1,… (mm). Float32 = drawRawPoints format
  final Float64List t;           // per-point time (s). Float64 keeps µs precision
  final Int32List strokeStart;   // length S+1. Points of stroke s = [strokeStart[s], strokeStart[s+1])
  final Float64List strokeT0;    // first-sample time of each stroke
  final Float64List strokeT1;    // last-sample time of each stroke
  final double width, height;    // ink bounds (mm)
  final double duration;         // t of last sample
  int get strokeCount => strokeStart.length - 1;
  int get pointCount => t.length;
}
```

Done **once at parse time** (via `compute`, which uses `Isolate.run` on mobile and desktop and also works on web):

1. metres → millimetres (×1000)
2. `t -= t[0]` (removes the ~0.97 s lead-in)
3. shift all points so the bounds' top-left is (0, 0), and record `width` / `height`
4. build `strokeStart`, `strokeT0` and `strokeT1` in a single pass

Built **once per note, in the UI layer**, by `NoteReplayViewModel`:

- `List<Float32List> strokeXY`: one `Float32List.sublistView` per stroke (S small views
  that share the same buffer). The painters draw from these, so no `Path` is ever built.

---

## 5. Rendering pipeline

### 5.1 How a frame is produced

```
 display vsync (60/90/120 Hz)
        │
        ▼
 Ticker(elapsed)  ── FrameClock ──▶  NoteReplayViewModel._onTick(elapsed)
                                        │ 1. T = timeline.replayTime(elapsed)      O(1)
                                        │ 2. cursor.advanceTo(T) → ReplayFrame     O(new samples)
                                        │ 3. if committed count changed:
                                        │       committedStrokes.value = k         (≈ once per stroke)
                                        │ 4. frame.notify()                         (every frame)
                                        │ 5. if T ≥ end: stop ticker, status = completed
                                        ▼
         ┌──────────────────────────────┴───────────────────────────────┐
         ▼                                                              ▼
 ActiveInkPainter (repaint: frame)                  CommittedInkPainter (repaint: committedStrokes)
 RepaintBoundary #2 — every frame                   RepaintBoundary #1 — ≈ S times per replay
 draws ONE partial stroke + pen tip                 draws strokes [0, k) — layer kept between frames
         │                                                              │
         └─────────────── compositor (layer tree, raster thread) ──────┘
```

There is **no build phase and no layout phase** inside this loop. `CustomPaint(repaint: …)`
hooks the listenable straight to `RenderCustomPaint.markNeedsPaint()`, so a tick only marks
the paint of the render object it belongs to as dirty.

### 5.2 Two layers: committed ink and active ink

| Layer | Content | Repaints when | Per-repaint cost |
|---|---|---|---|
| **Committed** (bottom) | Strokes that finished before `T` | The committed count changes: about once per stroke (8–24 times per replay), or on seek | S × `drawRawPoints` |
| **Active** (top) | The stroke being drawn at `T`: its samples up to `T` plus an interpolated pen-tip segment, and an optional pen-tip dot | Every frame while playing | 1–3 draw calls |

Each layer sits inside its own `RepaintBoundary`, so it gets its own compositing layer.
While a stroke is being drawn, the committed layer's picture is **reused unchanged** by the
compositor. Per frame, only the small active-layer picture is recorded again. This gives
the benefit of caching the drawn ink without managing a `ui.Picture` by hand.

### 5.3 Drawing: one transform per frame, never per point

- The points are stored in millimetres, in note space. The fit-to-canvas transform is a
  single `canvas.translate(dx, dy); canvas.scale(s);` at the start of `paint()`. The GPU
  applies it to the vertices, so **the CPU never transforms a point**.
- `s = min((w − 2p) / note.width, (h − 2p) / note.height)` and the centring offset are
  computed only when the canvas size changes. They are cached in a `ViewportTransform`
  held by `ReplayCanvas`'s `LayoutBuilder` (one rebuild per resize, never per frame).
- Line width is set in **millimetres** (for example 0.45 mm), so it scales with the note.

### 5.4 Drawing primitive

Both layers use the same primitive, so a stroke **does not change look** when it moves from
the active layer to the committed layer:

```dart
canvas.drawRawPoints(PointMode.polygon, strokeView, inkPaint);
// inkPaint: style=stroke, strokeCap=round, strokeJoin=round, isAntiAlias=true
```

- `PointMode.polygon` with round caps draws a connected polyline with round joins. At about
  0.05 mm between points it looks smooth, so no Bézier fitting is needed.
- The active stroke's visible prefix is `Float32List.sublistView(note.xy, 2*start, 2*(i+1))`.
  This creates a small view object; **no point data is copied**.
- The pen-tip segment from the last sample `i` to the interpolated position at `T` goes in a
  **reused** `Float32List(4)` scratch buffer, drawn with `PointMode.lines`.
- A stroke with a single visible sample is drawn with `PointMode.points` (round cap), so
  dots appear right away.
- **Limitation:** overlapping round caps double up when the ink is semi-transparent, so ink
  must be fully opaque. If translucent ink is needed later, wrap each stroke in
  `saveLayer`, or switch to a `Path` built once per stroke at load time.

### 5.4.1 Sketch: the active painter

```dart
class ActiveInkPainter extends CustomPainter {
  ActiveInkPainter({required this.frame, required this.geometry, required this.viewport,
      required this.ink})
      : super(repaint: frame);

  final ReplayFrame frame;          // mutable snapshot, written by the ViewModel on each tick
  final NoteGeometry geometry;      // note + per-stroke views, built once
  final ViewportTransform viewport; // cached; recomputed only on resize
  final Paint ink;                  // built once in InkStyle (never inside paint)

  @override
  void paint(Canvas canvas, Size size) {
    final s = frame.activeStroke;
    if (s < 0) return;
    canvas
      ..translate(viewport.dx, viewport.dy)
      ..scale(viewport.scale);
    final start = geometry.note.strokeStart[s];
    final end = frame.visibleEnd; // exclusive index of the last sample with t ≤ T, plus one
    if (end - start >= 2) {
      canvas.drawRawPoints(PointMode.polygon,
          Float32List.sublistView(geometry.note.xy, 2 * start, 2 * end), ink);
    }
    if (frame.hasHead) canvas.drawRawPoints(PointMode.lines, frame.headSegment, ink);
  }

  @override
  bool shouldRepaint(ActiveInkPainter old) =>
      old.geometry != geometry || old.viewport != viewport || old.ink != ink;
}
```

### 5.5 Per-frame budget, and what is never done per frame

Work per frame while playing, for each part of the loop:

| Step | Cost |
|---|---|
| Clock → `T` | Several arithmetic operations |
| Cursor advance | O(samples since last frame): about 7 at 60 Hz, about 3–4 at 120 Hz |
| Pen-tip interpolation | 1 linear interpolation, written into the reused buffer |
| Active paint | 1 `translate`, 1 `scale`, 1–3 `drawRawPoints` |
| Committed paint | **0**, except on the frame where a stroke completes |
| Build / layout | **0** |

**Never done per frame** (each rule maps to R6):

| Forbidden in the frame path | Where it happens instead |
|---|---|
| Creating `Paint`, `Path`, `Offset` lists, `Rect`, closures | `InkStyle` (once), `NoteGeometry` (once per note) |
| Transforming coordinates on the CPU | Canvas matrix (GPU) |
| Building or extending a `Path` | Not used. Stroke views are prepared once |
| Scanning all points or strokes | Forward-only cursor. Binary search only on seek |
| Formatting strings (time label) | A separate notifier, updated only when the 0.1 s value changes ([§7](#7-rebuild-and-repaint-isolation)) |
| `setState` / `notifyListeners` on page-level state | Only the dedicated `frame` listenable fires per frame |

### 5.6 The cursor: no full scans

`ReplayCursor` keeps `(stroke s, point i)` from the previous frame.

- **Forward playback (normal case):** `advanceTo(T)` steps forward while `t[i+1] ≤ T` and
  moves to the next stroke when the current stroke's `T1 ≤ T`. The total work over a whole
  replay is O(N), which is O(1) per frame on average.
- **Seek or going backwards:** binary search `strokeT0` (O(log S)), then binary search the
  stroke's points (O(log P)). This is the only time binary search runs.
- **Output** goes into the reused `ReplayFrame` object: `committedCount`, `activeStroke`,
  `visibleEnd`, `hasHead`, `headSegment` (`Float32List(4)`), and `penX` / `penY`.

---

## 6. Timestamp accuracy

The frame rate decides **when we look**. The recording decides **what is drawn**. The two
are never mixed together.

### 6.1 Clock source

```
T_replay = anchorReplayTime + (frameElapsed − anchorElapsed) × speed
```

- `frameElapsed` is the `Duration` that `Ticker` passes to its callback. It comes from the
  **vsync frame timestamp** (`SchedulerBinding.currentFrameTimeStamp`), not `DateTime.now()`
  and not a counter of frames.
- Because `T` is **recomputed from an anchor** on every frame, and never built up as
  `T += dt`, there is no drift, no rounding build-up, and no dependence on frame rate. The
  same note takes the same wall-clock time at 60 Hz, 120 Hz, or with dropped frames.
- **Re-anchoring** happens on play, speed change and seek:
  `anchorReplayTime = T_current; anchorElapsed = lastElapsed`. A `Ticker`'s `elapsed`
  restarts at zero each time it starts, so on play `anchorElapsed = Duration.zero`.

### 6.2 Sub-sample pen-tip position

Samples are 2.43 ms apart, while frames are 8.3–16.7 ms apart. Frames almost never land
exactly on a sample, so the pen tip is placed **at `T` exactly**:

```
i  = last sample with t[i] ≤ T
p  = p[i] + (p[i+1] − p[i]) · (T − t[i]) / (t[i+1] − t[i])
```

The drawn ink is exactly what the pen had written at time `T`: every sample up to `T`, plus
the partial segment. This holds whatever the display rate.

### 6.3 Dropped frames and catching up

If a frame is late, the next `T` is simply later. The cursor moves past all samples in
between and the active stroke draws all of them, so **ink is never skipped**. The animation
jumps forward but stays correct. Strokes that finished during the gap move to the committed
layer in the same frame.

### 6.4 Pause shortening and speed

- **Speed** (0.25× – 4×) only changes the clock formula. The recorded times are never changed.
- **Pause shortening** (optional, for example capping each pen-up gap at 0.25 s) uses
  `ReplayTimeline`. It stores a per-stroke `shift[s]` (time removed before stroke `s`) and
  replay-time stroke bounds `strokeT0R` / `strokeT1R`. Turning it on or off costs O(S)
  (S ≤ 24), not O(N). Within a stroke, recorded time is `t = T_replay + shift[s]`, so
  **timing inside a stroke stays exact**. Only the pauses get shorter.

### 6.5 Display latency

A frame stamped at time `T` appears on screen 1–2 vsyncs later. That delay is the same for
every frame, so the timing between strokes is still correct. Lip-sync-style compensation is
not needed.

---

## 7. Rebuild and repaint isolation

The `NoteReplayViewModel` exposes **separate listenables, one per update rate**. Each widget
listens only to the one it needs:

| Listenable | Fires | Listener | Result |
|---|---|---|---|
| `status` (`ValueListenable<PlaybackStatus>`: idle/playing/paused/completed, speed, pause shortening) | On user action or when playback ends | `PlaybackControls` via `ValueListenableBuilder` | Rebuilds the controls only, rarely |
| `committedStrokes` (`ValueListenable<int>`) | About once per stroke, or on seek | `CommittedInkPainter(repaint:)` | **Repaint only**, no rebuild |
| `frame` (`ReplayFrame extends ChangeNotifier`) | Every vsync while playing | `ActiveInkPainter(repaint:)`, `ReplayProgressBar` painter (`repaint:`) | **Repaint only**, no rebuild |
| `clockLabel` (`ValueListenable<int>`, tenths of a second) | 10 times a second at most | A single `Text` | Rebuilds one leaf widget at 10 Hz. Can be turned off |

Rules that keep the page from rebuilding:

1. `NoteReplayScreen.build` runs once per route (and on resize). It never listens to `frame`.
2. The ViewModel **never** calls its own `notifyListeners()` from `_onTick`.
3. Painters are configured once (constructor fields compared by identity in `shouldRepaint`).
   All changing data is read from `ReplayFrame` during `paint()`.
4. `RepaintBoundary` wraps (a) the committed layer, (b) the active layer, and (c) the
   progress bar, so repaints never spread to the app bar, controls or route.
5. The progress bar is a `CustomPaint`, not a `Slider` rebuilt every frame. Dragging calls
   `viewModel.seek(T)` (O(log N)).
6. When playback is **paused or completed, the ticker is stopped**. No frames are scheduled,
   so idle uses no CPU or battery.
7. `TickerMode` (from `TickerProvider`) silences the ticker when the route is covered.

How to check: DevTools *Track widget rebuilds* should show 0 rebuilds per frame during
playback. `debugRepaintRainbowEnabled` should show only the canvas and progress-bar layers
changing colour. A widget test also checks this ([§10](#10-testing-strategy)).

### 7.1 `FrameClock`: keeping `Ticker` out of the ViewModel's logic

```dart
abstract interface class FrameClock {
  void start(void Function(Duration elapsed) onTick);
  void stop();
  void dispose();
}

/// Production version: wraps a Ticker from the View's TickerProvider (vsync + TickerMode).
final class TickerFrameClock implements FrameClock { … }
```

`NoteReplayScreen`'s `State` mixes in `SingleTickerProviderStateMixin`. It creates the
ViewModel in `initState` with `TickerFrameClock(this)` and disposes it in `dispose`. Unit
tests pass a `ManualFrameClock` and push exact `elapsed` values in, so playback logic is
tested without any frames.

---

## 8. High refresh rate (60–120 Hz)

- `Ticker` fires once per engine frame, and the engine frame rate follows the display. Our
  code never assumes 60 Hz, because every frame computes `T` from the timestamp ([§6.1](#61-clock-source)).
- **iOS ProMotion:** add `CADisableMinimumFrameDurationOnPhone = true` to `ios/Runner/Info.plist`.
  Without it, iPhones are limited to 60 Hz.
- **Android:** Flutter renders at whatever mode the display is in. Most high-refresh devices
  switch to it on their own. If testing shows a device stuck at 60 Hz, add a small optional
  platform step (`Surface.setFrameRate` / preferred display mode) later. It is not needed in v1.
- **Budget:** 8.3 ms per frame at 120 Hz. The per-frame work in [§5.5](#55-per-frame-budget-and-what-is-never-done-per-frame)
  is far below that on both UI and raster threads. Impeller (the default on iOS and Android)
  draws `drawRawPoints` polylines directly.
- Profile only in `--profile` mode, on a real device, with the performance overlay and the
  DevTools frame chart.

---

## 9. Edge cases

| Case | Handling |
|---|---|
| Lead-in before the first sample (~0.97 s) | Removed at parse time |
| Long pauses (up to 2.07 s in note_5) | Played as recorded, unless pause shortening is on |
| Dot strokes (0.6 mm) | Round caps. `PointMode.points` when only 1 sample is visible |
| Rotated text (note_3) | Drawn as recorded |
| Seeking backwards | Binary search, and the committed layer repaints once |
| Rotation or resize while playing | `ViewportTransform` is recomputed once. Playback continues without interruption |
| App goes to background | Ticker silenced. The anchor is reset when playback resumes, so the replay doesn't jump ahead |
| Bad CSV (missing column, unparseable number, stroke ids out of order) | Parser returns `Result.error` and the View shows an error state. A note is never partly drawn |
| Empty note | The `Result.error` path is the same as a bad CSV |

---

## 10. Testing strategy

| Level | Target | Examples |
|---|---|---|
| Unit | `NoteCsvParser` | Units and normalisation, stroke table, scientific notation, bad input → error |
| Unit | `ReplayCursor` | Forward advance matches a brute-force reference at random `T`. Seek forwards and backwards. Stroke boundaries. Pen tip at exact sample times |
| Unit | `ReplayTimeline` | Pause shortening keeps timing inside strokes and stays monotonic. Speed changes re-anchor without a jump |
| Unit | `NoteReplayViewModel` | With `ManualFrameClock`: play → ticks → completed. Pause stops the clock. Seek updates `committedStrokes` |
| Widget | `NoteReplayScreen` | Build counters show **0 page or control rebuilds over 100 ticks**. Controls rebuild once per status change |
| Golden | `ReplayCanvas` | Frames at fixed `T` (0, mid-stroke, between strokes, end) for each note. Deterministic, because a frame depends only on `T` |
| Manual perf | Device in profile mode | 120 Hz iPhone and a high-refresh Android: no janky frames across a full replay of note_2 (the largest) |

---

## 11. Implementation steps

1. **Data:** move the CSVs to `assets/notes/`, then write `Note`, `NoteCsvParser`, `NoteAssetService`, `NoteRepository` and `Result`, plus parser tests.
2. **Playback core (pure Dart):** `ReplayTimeline`, `ReplayCursor`, `ReplayFrame`, `FrameClock` and `ManualFrameClock`, plus their tests.
3. **Replay ViewModel:** commands (play/pause/seek/speed/pause shortening), the separate listenables, and lifecycle handling.
4. **Canvas:** `ViewportTransform`, `CommittedInkPainter`, `ActiveInkPainter`, `RepaintBoundary` layout, and golden tests.
5. **Screens:** note list → replay screen, controls, progress bar, and the rebuild-isolation widget test.
6. **Performance pass:** Info.plist ProMotion key, profiling on device, and checking with rebuild and repaint tracking.
7. **Optional:** pen-tip indicator style, line width based on speed, straightening note_3, video/GIF export by sampling `T`.
