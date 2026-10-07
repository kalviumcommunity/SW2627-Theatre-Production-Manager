import 'package:flutter/material.dart';

void main() {
  runApp(const TheatreProductionManager());
}

class TheatreProductionManager extends StatelessWidget {
  const TheatreProductionManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Theatre Production Manager',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theatre Production Manager'),
      ),
      body: const Center(
        child: Text(
          'Theatre Production Manager',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}