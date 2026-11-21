import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_sim/game/upgrades.dart';
import 'package:space_sim/game_controller.dart';
import 'package:space_sim/main.dart';

void main() {
  for (final (name, size) in [
    ('phone', const Size(400, 860)),
    ('fold inner', const Size(770, 580)),
  ]) {
    testWidgets('home screen renders on $name', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await GameController.load();
      c.state.credits = 50;
      await tester.pumpWidget(SpaceSimApp(controller: c));
      expect(find.text('Sol Fringe I'), findsOneWidget);
      expect(find.text('UPGRADES'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Cannons  ·  Lv 0'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump();
      expect(c.state.levels[Upgrade.cannons], 1);
    });
  }

  testWidgets('shows the offline report after time away', (tester) async {
    final then = DateTime(2026, 1, 1, 12);
    SharedPreferences.setMockInitialValues({
      'save': '{"v":1,"credits":0,"sector":1}',
      'last_seen_ms': then.millisecondsSinceEpoch,
    });
    final c = await GameController.load(
      now: () => then.add(const Duration(hours: 2)),
    );
    expect(c.pendingReport, isNotNull);
    await tester.pumpWidget(SpaceSimApp(controller: c));
    await tester.pump();
    expect(find.text('While you were away'), findsOneWidget);
    await tester.tap(find.text('Collect'));
    await tester.pumpAndSettle();
    expect(c.pendingReport, isNull);
  });
}
