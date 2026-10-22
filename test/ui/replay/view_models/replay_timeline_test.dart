import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/ui/replay/view_models/replay_timeline.dart';

void main() {
  test('time follows the clock from the anchor', () {
    final timeline = ReplayTimeline(duration: 10)
      ..anchor(2, const Duration(seconds: 1));

    expect(timeline.timeAt(const Duration(seconds: 1)), 2);
    expect(timeline.timeAt(const Duration(milliseconds: 1500)), 2.5);
  });

  test('does not drift over many frames', () {
    final timeline = ReplayTimeline(duration: 1000)..anchor(0, Duration.zero);

    // 100,000 frames at 120 Hz, each computed from the clock, not summed.
    const frame = Duration(microseconds: 8333);
    final time = timeline.timeAt(frame * 100000);

    expect(time, closeTo(833.3, 1e-9));
  });

  test('applies speed', () {
    final timeline = ReplayTimeline(duration: 10, speed: 2)
      ..anchor(1, Duration.zero);

    expect(timeline.timeAt(const Duration(seconds: 1)), 3);
  });

  test('re-anchoring continues from the new point without a jump', () {
    final timeline = ReplayTimeline(duration: 10)..anchor(0, Duration.zero);
    final before = timeline.timeAt(const Duration(seconds: 3));

    timeline.anchor(before, Duration.zero);

    expect(timeline.timeAt(Duration.zero), before);
  });

  test('clamps to [0, duration]', () {
    final timeline = ReplayTimeline(duration: 5)..anchor(4, Duration.zero);

    expect(timeline.timeAt(const Duration(seconds: 10)), 5);
    timeline.anchor(-3, Duration.zero);
    expect(timeline.timeAt(Duration.zero), 0);
  });
}
