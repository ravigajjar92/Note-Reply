import 'package:note_replay_animation/ui/replay/view_models/frame_clock.dart';

/// A [FrameClock] that ticks only when the test calls [tick].
class ManualFrameClock implements FrameClock {
  void Function(Duration elapsed)? _onTick;
  bool _running = false;
  bool disposed = false;

  @override
  bool get isRunning => _running;

  @override
  void start(void Function(Duration elapsed) onTick) {
    _onTick = onTick;
    _running = true;
  }

  @override
  void stop() => _running = false;

  @override
  void dispose() {
    _running = false;
    disposed = true;
  }

  /// Delivers one frame at [elapsed] since the last start, if running.
  void tick(Duration elapsed) {
    if (_running) _onTick!(elapsed);
  }
}
