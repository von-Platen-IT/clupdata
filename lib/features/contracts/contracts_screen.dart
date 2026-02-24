import 'package:flutter/material.dart';

/// The main view for managing member contracts.
///
/// Currently shows a placeholder, but will eventually allow users to 
/// create, bind, and manage workout plans or memberships.
class ContractsScreen extends StatelessWidget {
  /// Creates the contracts screen.
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verträge')),
      body: const Center(child: Text('Verträge kommen bald...')),
    );
  }
}
