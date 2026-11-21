import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:space_sim/game/upgrades.dart';
import 'package:space_sim/game_controller.dart';
import 'package:space_sim/main.dart';
import 'package:space_sim/services/breakdown_alerts.dart';

class FakeAlerts implements BreakdownAlerts {
  final scheduled = <DateTime>[];
  var cancels = 0;

  @override
  Future<void> scheduleAt(DateTime at) async => scheduled.add(at);

  @override
  Future<void> cancel() async => cancels++;
}

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

  testWidgets('leaving schedules the breakdown alert; returning cancels it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 1, 1, 12);
    final alerts = FakeAlerts();
    final c = await GameController.load(now: () => now, alerts: alerts);
    await tester.pumpWidget(SpaceSimApp(controller: c));
    c.start();
    final cancels0 = alerts.cancels;
    final left = c.state.timeToBreakdown;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(alerts.scheduled, [now.add(left)]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(alerts.cancels, greaterThan(cancels0));
    c.dispose();
  });

  testWidgets('a broken-down ship shows the repair overlay', (tester) async {
    SharedPreferences.setMockInitialValues({
      'save': '{"v":2,"sector":3,"integrity":0}',
    });
    final c = await GameController.load();
    await tester.pumpWidget(SpaceSimApp(controller: c));
    expect(find.text('Ship broken down'), findsOneWidget);
    await tester.tap(find.text('Repair ship'));
    await tester.pump();
    expect(c.state.disabled, isFalse);
    expect(find.text('Ship broken down'), findsNothing);
  });

  testWidgets('galaxy jump asks first, then resets the run', (tester) async {
    SharedPreferences.setMockInitialValues({
      'save': '{"v":2,"sector":30,"credits":500}',
    });
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await GameController.load();
    await tester.pumpWidget(SpaceSimApp(controller: c));
    await tester.tap(find.text('Jump for +4 Dark Matter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jump'));
    await tester.pumpAndSettle();
    expect(c.state.darkMatter, 4);
    expect(c.state.sector, 1);
  });
}
