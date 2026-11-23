import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/app_shell.dart';

void main() {
  runApp(const StatisticsApp());
}

class StatisticsApp extends StatelessWidget {
  const StatisticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUE Statistics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
