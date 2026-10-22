/// Converts frame-clock time into playback time.
///
/// Playback time is recomputed from an anchor on every frame, never summed
/// from frame deltas, so it can't drift and doesn't depend on the frame rate.
final class ReplayTimeline {
  ReplayTimeline({required this.duration, this.speed = 1});

  /// Length of the note in seconds.
  final double duration;

  /// Playback speed. 1 is the speed it was written at.
  final double speed;

  double _anchorTime = 0;
  Duration _anchorElapsed = Duration.zero;

  /// Makes [elapsed] on the frame clock correspond to playback [time].
  void anchor(double time, Duration elapsed) {
    _anchorTime = _clamp(time);
    _anchorElapsed = elapsed;
  }

  /// The playback time at [elapsed] on the frame clock, within
  /// `[0, duration]`.
  double timeAt(Duration elapsed) {
    final seconds =
        (elapsed - _anchorElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    return _clamp(_anchorTime + seconds * speed);
  }

  double _clamp(double time) =>
      time < 0 ? 0 : (time > duration ? duration : time);
}
