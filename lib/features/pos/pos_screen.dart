import 'package:flutter/material.dart';

/// The main view for the Point-of-Sale (POS) system.
///
/// Currently shows a placeholder, but will eventually provide an interface
/// for staff to sell items (e.g., drinks, gear) to members or guests and
/// record these transactions.
class PosScreen extends StatelessWidget {
  /// Creates the POS screen.
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasse / POS')),
      body: const Center(child: Text('Kasse kommt bald...')),
    );
  }
}
