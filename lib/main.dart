import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'services/breakdown_alerts.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final alerts = LocalBreakdownAlerts();
  await alerts.init();
  final controller = await GameController.load(alerts: alerts);
  controller.start();
  runApp(SpaceSimApp(controller: controller));
}

class SpaceSimApp extends StatelessWidget {
  const SpaceSimApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return GameScope(
      controller: controller,
      child: MaterialApp(
        title: 'Space Sim',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
