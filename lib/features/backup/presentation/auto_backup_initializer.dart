import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'providers/backup_providers.dart';

/// Startet das Auto-Backup genau einmal nach dem ersten gerenderten Frame.
///
/// Der Hintergrund-Task läuft asynchron und blockiert die UI nicht
/// (kein modal-Dialog, siehe `plans/backup-konzept.md`).
/// Eingehängt als `builder` in `MaterialApp.router`.
class AutoBackupInitializer extends HookConsumerWidget {
  final Widget child;

  const AutoBackupInitializer({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(autoBackupStatusProvider.notifier).starteWennFaellig();
      });
      return null;
    }, []);
    return child;
  }
}
