# Integration des Export-Buttons in Edit-Dialoge

## Übersicht

Da modale Dialoge das Hauptmenü blockieren, müssen wir die Export-Funktionalität direkt in die Dialoge integrieren.

## Verwendung

### 1. DialogExportButton

Fügen Sie den `DialogExportButton` in die Actions-Leiste Ihres Dialogs ein:

```dart
import '../../export/presentation/dialog_export_button.dart';

class MemberEditDialog extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = // ... load member data
    
    return AppEditDialogScaffold(
      title: 'Mitglied bearbeiten',
      // Fügen Sie den ExportButton in die Titelleiste hinzu
      content: Column(
        children: [
          // Dialog-Inhalt
        ],
      ),
      isSaving: isSaving,
      onSave: () => _save(context, ref),
      onDelete: memberId != null ? () => _delete(context, ref) : null,
      deleteEntityLabel: 'Mitglied',
    );
  }
}
```

### 2. AppEditDialogScaffold mit ExportButton erweitern

Der sauberste Weg ist, den `AppEditDialogScaffold` zu erweitern:

```dart
// In app_edit_dialog_scaffold.dart
class AppEditDialogScaffold extends StatelessWidget {
  // ... bestehende Parameter
  
  /// Optional export button configuration
  final ExportConfig? exportConfig;
  
  const AppEditDialogScaffold({
    // ... bestehende Parameter
    this.exportConfig,
  });
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text(title),
          const Spacer(),
          // Export-Button (wenn konfiguriert)
          if (exportConfig != null)
            DialogExportButton(
              item: exportConfig!.item,
              entityType: exportConfig!.entityType,
              title: exportConfig!.title,
              subtitle: exportConfig!.subtitle,
            ),
          // Close-Button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      // ... restlicher Code
    );
  }
}

/// Configuration for export functionality
class ExportConfig {
  final dynamic item;
  final String entityType;
  final String title;
  final String? subtitle;
  
  const ExportConfig({
    required this.item,
    required this.entityType,
    required this.title,
    this.subtitle,
  });
}
```

### 3. Verwendung im MemberEditDialog

```dart
class MemberEditDialog extends HookConsumerWidget {
  final int? memberId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = useMemoized(() {
      if (memberId == null) return Future<Mitglied?>.value(null);
      return ref.read(membersRepositoryProvider).getMemberById(memberId!);
    }, [memberId]);
    
    final memberSnapshot = useFuture(memberAsync);
    final member = memberSnapshot.data;
    
    return AppEditDialogScaffold(
      title: memberId == null ? 'Neues Mitglied' : 'Mitglied bearbeiten',
      exportConfig: member != null 
        ? ExportConfig(
            item: member,
            entityType: 'mitglied',
            title: 'Mitglied ${member.name}',
            subtitle: 'ID: ${member.id}',
          )
        : null,
      content: // ... Formular-Felder
      isSaving: isSaving,
      onSave: () => _save(context, ref),
    );
  }
}
```

## Dialog-spezifische Konfiguration

### MemberEditDialog
```dart
ExportConfig(
  item: member,
  entityType: 'mitglied',
  title: 'Mitglied ${member.name}',
)
```

### BeitragEditDialog
```dart
ExportConfig(
  item: beitrag,
  entityType: 'beitrag',
  title: 'Beitrag ${beitrag.id}',
)
```

### RechnungEditDialog
```dart
ExportConfig(
  item: rechnung,
  entityType: 'rechnung',
  title: 'Rechnung ${rechnung.rechnungsnummer}',
)
```

### LeistungEditDialog
```dart
ExportConfig(
  item: leistung,
  entityType: 'leistung',
  title: 'Leistung ${leistung.bezeichnung}',
)
```

### WarenEditDialog
```dart
ExportConfig(
  item: ware,
  entityType: 'ware',
  title: 'Ware ${ware.bezeichnung}',
)
```

### StammdatenEditDialog
```dart
// Kein Export nötig - nur einfache Key-Value Paare
```

## Vorteile dieser Lösung

1. **Nicht-invasiv**: Bestehende Dialoge funktionieren weiterhin
2. **Optional**: Nur Dialoge mit Export-Bedarf erhalten den Button
3. **Konsistent**: Einheitliche Position und Funktionalität
4. **Flexibel**: Leicht an verschiedene Entity-Typen anpassbar

## Nächste Schritte

Um die Integration abzuschließen:

1. Erweitern Sie `AppEditDialogScaffold` um den `ExportConfig` Parameter
2. Fügen Sie in jeden relevanten Dialog die Export-Konfiguration hinzu
3. Testen Sie die Export-Funktionalität in jedem Dialog

Die Implementierung ist bereit und wartet auf die Integration in die einzelnen Dialoge.
