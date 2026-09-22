import 'package:flutter/material.dart';

class PreflopScreen extends StatelessWidget {
  const PreflopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preflop'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Charts coming soon!')),
                  );
                },
                child: const Text('Charts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
