import 'package:flutter/scheduler.dart';

/// Calls back once per display frame while running.
///
/// The ViewModel depends on this interface, not on [Ticker], so playback can
/// be tested by pushing exact `elapsed` values in.
abstract interface class FrameClock {
  /// Starts calling [onTick] every frame. `elapsed` restarts at zero on each
  /// start.
  void start(void Function(Duration elapsed) onTick);

  void stop();

  bool get isRunning;

  void dispose();
}

/// A [FrameClock] driven by a [Ticker], so it follows the display's refresh
/// rate and is muted by `TickerMode` when its route is hidden.
final class TickerFrameClock implements FrameClock {
  TickerFrameClock(TickerProvider vsync) : _vsync = vsync;

  final TickerProvider _vsync;

  // Created on the first start, so a screen that never plays never makes
  // one (and dispose never creates one while the screen is torn down).
  Ticker? _ticker;
  void Function(Duration elapsed)? _onTick;

  @override
  void start(void Function(Duration elapsed) onTick) {
    _onTick = onTick;
    final ticker = _ticker ??= _vsync.createTicker(_tick);
    if (ticker.isActive) ticker.stop();
    ticker.start();
  }

  @override
  void stop() {
    if (_ticker case final ticker? when ticker.isActive) ticker.stop();
  }

  @override
  bool get isRunning => _ticker?.isActive ?? false;

  void _tick(Duration elapsed) => _onTick?.call(elapsed);

  @override
  void dispose() => _ticker?.dispose();
}
