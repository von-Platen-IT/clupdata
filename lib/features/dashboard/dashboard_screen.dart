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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image (Scaling to fit dashboard bounds, keeping proportions)
          Image.asset(
            'lib/assets/boxshule_start_pict.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.sports_mma, 
                  size: 120, 
                  color: Theme.of(context).colorScheme.primary
                ),
              );
            },
          ),
          // Text Overlay
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Willkommen im Boxclub!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
