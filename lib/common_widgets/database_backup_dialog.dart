import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/data/database_backup_service.dart';
import '../core/providers/database_provider.dart';

/// Zeigt einen Modal-Dialog mit Fortschrittsanzeige während Backup/Restore.
class BackupProgressDialog extends StatelessWidget {
  final String message;

  const BackupProgressDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Datenbank'),
      content: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Text(message),
        ],
      ),
    );
  }

  /// Zeigt den Dialog und gibt den Close-Callback zurück.
  static VoidCallback show(BuildContext context, {required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackupProgressDialog(message: message),
    );
    return () => Navigator.of(context, rootNavigator: true).pop();
  }
}

/// Backup-Dialog: Speicherort wählen und Backup ausführen.
Future<void> showBackupDialog(BuildContext context, WidgetRef ref) async {
  final fileName = DatabaseBackupService.defaultBackupFileName();

  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Datenbank-Backup speichern',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['sqlite'],
  );

  if (result == null || !context.mounted) return;

  final closeDialog = BackupProgressDialog.show(
    context,
    message: 'Backup wird erstellt...',
  );

  try {
    final db = ref.read(appDatabaseProvider);
    await DatabaseBackupService.backup(db, result);
    closeDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup erfolgreich erstellt')),
      );
    }
  } catch (e) {
    closeDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fehler beim Backup: $e')));
    }
  }
}

/// Restore-Dialog: Bestätigung → Datei wählen → Restore ausführen.
Future<void> showRestoreDialog(BuildContext context, WidgetRef ref) async {
  // 1. Bestätigungsdialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Datenbank wiederherstellen'),
      content: const Text(
        'Die aktuelle Datenbank wird durch das Backup ersetzt. '
        'Alle aktuellen Daten gehen dabei verloren.\n\n'
        'Möchten Sie fortfahren?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Wiederherstellen'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // 2. Datei auswählen
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Backup-Datei auswählen',
    type: FileType.custom,
    allowedExtensions: ['sqlite'],
  );

  if (result == null || result.files.isEmpty || !context.mounted) return;

  final filePath = result.files.single.path;
  if (filePath == null || !context.mounted) return;

  // 3. SQLite-Datei validieren
  final isValid = await DatabaseBackupService.isValidSqliteFile(filePath);
  if (!isValid && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ungültige SQLite-Datenbankdatei')),
    );
    return;
  }

  if (!context.mounted) return;

  // 4. Restore ausführen
  final closeDialog = BackupProgressDialog.show(
    context,
    message: 'Datenbank wird wiederhergestellt...',
  );

  try {
    // DB-Instanz vor Invalidierung holen
    final db = ref.read(appDatabaseProvider);
    await DatabaseBackupService.restore(db, filePath);

    // DB-Provider invalidieren → wird automatisch neu geöffnet
    ref.invalidate(appDatabaseProvider);

    closeDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datenbank erfolgreich wiederhergestellt'),
        ),
      );
    }
  } catch (e) {
    // Bei Fehler trotzdem Provider invalidieren für sauberen Zustand
    ref.invalidate(appDatabaseProvider);
    closeDialog();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Wiederherstellung: $e')),
      );
    }
  }
}
