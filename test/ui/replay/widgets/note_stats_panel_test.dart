import 'package:flutter_test/flutter_test.dart';
import 'package:note_replay_animation/ui/replay/widgets/note_stats_panel.dart';

void main() {
  group('formatCount', () {
    test('adds thousands separators', () {
      expect(formatCount(0), '0');
      expect(formatCount(13), '13');
      expect(formatCount(999), '999');
      expect(formatCount(1478), '1,478');
      expect(formatCount(3788000), '3,788,000');
    });
  });

  group('formatMillis', () {
    test('shows milliseconds with two decimals', () {
      expect(formatMillis(2433), '2.43 ms');
      expect(formatMillis(140000), '140.00 ms');
      expect(formatMillis(0), '0.00 ms');
    });

    test('shows a dash when there is no interval', () {
      expect(formatMillis(null), '—');
    });
  });
}
