import 'package:flutter_test/flutter_test.dart';
import 'package:space_sim/services/breakdown_alerts.dart';

void main() {
  group('alertTimeFor (quiet hours 23:00–08:00, local time)', () {
    test('daytime breakdowns alert on time', () {
      final t = DateTime(2026, 3, 10, 15, 20);
      expect(alertTimeFor(t), t);
    });

    test('late evening waits until 8am the next day', () {
      expect(
        alertTimeFor(DateTime(2026, 3, 10, 23, 30)),
        DateTime(2026, 3, 11, 8),
      );
    });

    test('small hours wait until 8am the same day', () {
      expect(
        alertTimeFor(DateTime(2026, 3, 11, 3, 5)),
        DateTime(2026, 3, 11, 8),
      );
    });

    test('month and year boundaries roll over', () {
      expect(
        alertTimeFor(DateTime(2026, 12, 31, 23, 59)),
        DateTime(2027, 1, 1, 8),
      );
    });

    test('quiet hours off: always on time', () {
      final t = DateTime(2026, 3, 11, 3, 5);
      expect(alertTimeFor(t, quietHours: false), t);
    });

    test('the edges: 22:59 and 08:00 are outside quiet hours', () {
      final a = DateTime(2026, 3, 10, 22, 59);
      final b = DateTime(2026, 3, 11, 8);
      expect(alertTimeFor(a), a);
      expect(alertTimeFor(b), b);
    });
  });
}
