import 'package:flutter/material.dart';

import 'preflop_screen.dart';
import 'theme.dart';

void main() {
  runApp(const PokerTrainingApp());
}

class PokerTrainingApp extends StatefulWidget {
  const PokerTrainingApp({super.key});

  @override
  State<PokerTrainingApp> createState() => _PokerTrainingAppState();
}

class _PokerTrainingAppState extends State<PokerTrainingApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Training',
      theme: ThemeData(
        colorScheme: AppTheme.lightColorScheme,
        useMaterial3: true,
        extensions: [AppTheme.lightChartColors],
      ),
      darkTheme: ThemeData(
        colorScheme: AppTheme.darkColorScheme,
        useMaterial3: true,
        extensions: [AppTheme.darkChartColors],
      ),
      themeMode: _themeMode,
      home: MainMenuScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainMenuScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: onToggleTheme,
          tooltip: 'Toggle Theme',
        ),
        title: const Text('Poker Training'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  textStyle: const TextStyle(fontSize: 24),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PreflopScreen(),
                    ),
                  );
                },
                child: const Text('Preflop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
