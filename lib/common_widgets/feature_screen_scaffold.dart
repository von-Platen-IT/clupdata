import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

/// Standardisierter Scaffold für alle tabellarischen Datenpflege-Ansichten
/// (z.B. Mitglieder, Leistungen, Waren) als Teil der "DataMaintenanceUi" Architektur.
///
/// Bietet eine einheitliche AppBar mit:
/// 1. Dem Screen-Titel.
/// 2. Einem "Neu" Button oben rechts (sofern [onCreateNew] übergeben wird).
/// 3. Einem "Löschen" Button, der nur klickbar ist, wenn eine Zeile selektiert wurde
///    (sofern [onDeleteSelection] übergeben wird).
class FeatureScreenScaffold extends HookWidget {
  /// Der Titel des Screens (z.B. 'Mitglieder').
  final String title;

  /// Das auszuführende Tabellen-Widget, das fast den gesamten Bildschirm einnimmt.
  /// (in der Regel eine Instanz von [AppDataGrid] via [MemberDataGrid] etc.)
  final Widget body;

  /// Optionaler Callback zum Erstellen eines neuen Eintrages. Zeigt den "Neu" Button.
  final VoidCallback? onCreateNew;

  /// Callback, der beim Klick auf den standardisierten "Löschen" Button aufgerufen wird.
  /// Übergeben wird das Objekt/die ID der **aktuell selektierten Zeile**.
  /// Ist null, wenn die Funktion für diesen Screen nicht vorgesehen ist.
  final VoidCallback? onDeleteSelection;

  /// State-Controlling, ob im zugehörigen DataGrid aktuell eine Zeile markiert ist.
  /// Wenn true, wird der Delete-Button aktiviert, andernfalls deaktiviert (ausgegraut).
  final bool hasSelection;

  /// Optionales Widget, das unterhalb der Tabelle angezeigt wird (z.B. für Bemerkungen),
  /// sofern [hasSelection] true ist.
  final Widget? bottomPanel;

  const FeatureScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.onCreateNew,
    this.onDeleteSelection,
    this.hasSelection = false,
    this.bottomPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (onDeleteSelection != null) ...[
            FilledButton.icon(
              // Button is visually muted if nothing is selected
              style: FilledButton.styleFrom(
                backgroundColor: hasSelection 
                  ? Theme.of(context).colorScheme.error 
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: hasSelection 
                  ? Theme.of(context).colorScheme.onError 
                  : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              onPressed: hasSelection ? onDeleteSelection : null,
              icon: const Icon(Icons.delete),
              label: const Text('Löschen'),
            ),
            const Gap(8),
          ],
          if (onCreateNew != null) ...[
            ElevatedButton.icon(
              onPressed: onCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('Neu'),
            ),
            const Gap(16),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(child: body),
          if (hasSelection && bottomPanel != null) bottomPanel!,
        ],
      ),
    );
  }
}
