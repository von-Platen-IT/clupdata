import 'package:flutter/material.dart';

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stammdaten (Legacy)')),
      body: const Center(child: Text('Wird migriert...')),
    );
  }
}
