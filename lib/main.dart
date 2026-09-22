import 'package:flutter/material.dart';

void main() {
  runApp(const PokerTrainingApp());
}

class PokerTrainingApp extends StatelessWidget {
  const PokerTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Training',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green, // Poker green theme
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                  // TODO: Navigate to Preflop training screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preflop training coming soon!')),
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
