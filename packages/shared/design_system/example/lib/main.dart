import 'package:flutter/material.dart';

import 'design_system_showcase.dart';

void main() {
  runApp(const DesignSystemShowcaseApp());
}

class DesignSystemShowcaseApp extends StatelessWidget {
  const DesignSystemShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Design System Showcase',
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const DesignSystemShowcase(),
    );
  }
}
