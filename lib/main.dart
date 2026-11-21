import 'package:flutter/material.dart';

import 'game_controller.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await GameController.load();
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
