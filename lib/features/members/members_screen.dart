import 'package:flutter/material.dart';
import 'widgets/member_data_grid.dart';

/// The main view for managing club members.
///
/// Currently shows a placeholder message.
class MembersScreen extends StatelessWidget {
  /// Creates the members screen.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
      ),
      body: MemberDataGrid(),
    );
  }
}
