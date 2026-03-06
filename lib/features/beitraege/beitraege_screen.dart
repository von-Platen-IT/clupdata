import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../common_widgets/feature_screen_scaffold.dart';

class BeitraegeScreen extends HookConsumerWidget {
  const BeitraegeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const FeatureScreenScaffold(
      title: 'Beiträge',
      hasSelection: false,
      body: Center(
        child: Text('Das Beitrags-Feature zur Verwaltung von Kursbeiträgen der Mitglieder kommt in Kürze.'),
      ),
    );
  }
}
