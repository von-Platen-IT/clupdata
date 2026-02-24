import 'package:flutter/material.dart';

/// The initial landing screen of the application.
///
/// This dashboard provides a high-level overview of the club's status
/// and acts as the default route when launching the app.
class DashboardScreen extends StatelessWidget {
  /// Creates the dashboard screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for Boxing Graphic
            Icon(Icons.sports_mma, size: 120, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Willkommen im Boxclub!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
