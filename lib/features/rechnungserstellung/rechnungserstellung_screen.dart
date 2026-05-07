import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../common_widgets/feature_screen_scaffold.dart';

/// Platzhalter-Screen für die Rechnungserstellung.
/// Zeigt nur den Menütext als Überschrift.
class RechnungserstellungScreen extends ConsumerWidget {
  final String title;

  const RechnungserstellungScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureScreenScaffold(
      title: 'Rechnungserstellung',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Diese Funktion ist noch nicht implementiert.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
