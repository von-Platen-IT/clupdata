# Datenbank-Migration & Seeding mit Drift in Flutter

Dieses Dokument beschreibt den typsicheren, Git-versionierten Workflow für Datenbankänderungen und Testdaten in unserer Flutter-App. Da wir `drift` als ORM für unsere lokale SQLite-Datenbank nutzen, verwenden wir dessen integrierte Werkzeuge, anstatt externe SQL-Tools einzusetzen.

## 1. Einführung: Warum Drift?

**Drift** ist eine typsichere Bibliothek für SQLite in Dart. Es generiert Code basierend auf unseren Dart-Tabellendefinitionen.
Wenn sich an unseren Tabellen etwas ändert (z. B. eine neue Spalte), muss das Datenbankschema auf den Geräten der Nutzer aktualisiert werden. Diesen Prozess nennt man **Migration**.
Außerdem benötigen wir oft **Testdaten (Seeding)** während der Entwicklung.

Beide Aspekte lösen wir komplett in Dart-Code. Der große Vorteil: Wenn sich Tabellen ändern, prüft der Dart-Compiler sofort, ob unsere Testdaten und Migrations-Logik noch korrekt sind (Compiler-Sicherheit). Zudem lässt sich alles sauber in Git versionieren.

---

## 2. Der Schema-Migrations-Workflow (Single Source of Truth)

Gemäß unseren Architektur-Richtlinien ist die Datei `lib/assets/data/structur.md` die **bestimmende Quelle (Single Source of Truth)** für unsere Datenstruktur. Jede Migration beginnt ZWINGEND dort!

Wenn du Tabellen veränderst (z. B. eine neue Spalte hinzufügst), folge exakt diesen Schritten:

### Schritt 2.1: Definition in `structur.md` anpassen
Bevor du Dart-Code anfässt, musst du das Schema in `lib/assets/data/structur.md` anpassen. Füge dort neue Tabellen, Felder oder Relationen hinzu. Dies stellt sicher, dass UI, Logik und Datenbank konsistent bleiben.

### Schritt 2.2: Dart Schema anpassen und Version erhöhen
Ändere nun passend zur `structur.md` deine Tabellen-Klassen (z. B. in `lib/core/database/tables/`) und erhöhe in deiner Datei `lib/core/database/database.dart` (wo `@DriftDatabase` steht) die `schemaVersion`:

```dart
@override
int get schemaVersion => 2; // Vorher 1, jetzt 2
```

### Schritt 2.3: Schema-Snapshot exportieren (Für Git)
Generiere einen Snapshot des neuen Schemas. Dieser Schritt wandelt deine Tabellen in maschinenlesbare JSON-Dateien um, die in Git versioniert werden. Führe im Terminal aus:

```bash
dart run drift_dev schema dump lib/core/database/database.dart drift_schemas/
```
*Tipp: Der Ordner `drift_schemas/` wird komplett in Git eingecheckt! Das ist unsere lückenlose Historie.*

### Schritt 2.4: Migrations-Hilfsklassen generieren
Lass Drift Code aus diesen JSON-Snapshots generieren, damit du die Migrationstests später typsicher schreiben kannst:

```bash
dart run drift_dev schema steps drift_schemas/ lib/core/database/schema_versions.dart
```

### Schritt 2.5: Migrations-Logik schreiben (Upgrade)
In deiner `database.dart` findest du die abstrakte Methode `migration`. Dort baust du den Upgrade-Pfad im `onUpgrade` Handler ein:

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      // Beispiel: Neue Spalte hinzufügen
      await m.addColumn(members, members.neueSpalte);
    }
  },
);
```

---

## 3. Git-Rollback: Was tun, wenn ich zu einem alten Commit zurückkehre?

Wenn du per `git checkout` oder `git reset` auf einen alten Commit (z. B. Zustand von Version 1) zurückspringst, passiert Folgendes:
Dein **Code** ist wieder alt, aber deine lokale SQLite-Datei auf der Festplatte deines Computers ist noch "neu" (Version 2). Die App wird beim Start abstürzen, weil Drift feststellt, dass die Datei neuer ist als der Code.

**Lösung während der Entwicklung:**
1. Gehe in Git auf den alten Commit zurück.
2. **Lösche die lokale Datenbankdatei** manuell von deiner Festplatte. (Wo diese liegt, hängt vom OS ab. Alternativ kannst du die App bei Emulatoren einfach löschen/neu installieren).
3. Starte die App neu. Die Datenbank wird passend zum alten Code frisch in Version 1 erstellt.

**Lösung in Produktion (für Endnutzer):**
Liefere *niemals* ein Downgrade der `schemaVersion` an Endnutzer aus! Erhöhe die Version stattdessen (z.B. auf Version 3) und schreibe einen `onUpgrade` Schritt, der die fehlerhafte Code-Änderung von Version 2 rückgängig macht (z. B. `await m.dropColumn(...)`).

---

## 4. Testdaten anlegen (Seeding)

Um Testdaten zu pflegen, nutzen wir typsichere Drift `Companions`. Bei jeder Tabellen-Änderung in der Zukunft zwingt uns der Compiler dann, auch unsere Testdaten aktuell zu halten.

### Schritt 4.1: Testdaten-Datei anlegen
Erstelle einen Ordner z.B. `lib/core/database/seeding/` und darin Dateien wie `demo_members.dart`. Lege dort deine Daten als Arrays/Listen an:

```dart
import 'package:drift/drift.dart';
import '../database.dart'; // Importiere deine generierte Datenbank

final List<MembersCompanion> demoMembers = [
  MembersCompanion.insert(
    firstName: 'Max',
    lastName: 'Mustermann',
    email: const Value('max@example.com'),
    // ... fülle alle Pflichtfelder korrekt aus
  ),
  // Weitere Mustermitglieder ...
];
```

### Schritt 4.2: Seeding-Funktion in die Datenbank aufnehmen
Nutze in deiner `AppDatabase` (oder einem eigenem Repository/Service) die `batch`-Funktion, um Massendaten rasend schnell einzufügen:

```dart
Future<void> seedDatabase() async {
  await batch((batch) {
    batch.insertAll(members, demoMembers);
    // Beachte Relationen: Zuerst abhängige Stammdaten einfügen (z.B. Berufe/Orte), 
    // dann die Tabellen, die darauf verweisen!
  });
}
```

### Schritt 4.3: Auslöseregel (Wann wird geseedet?)
Es gibt zwei praxisnahe Wege:
- **Automatisch bei Neu-Erstellung:** Rufe `await seedDatabase();` direkt in deiner `onCreate`-Migration nach `await m.createAll();` auf. (Dies füllt die Datenbank beim allerersten Start).
- **Entwickler-Button (Empfohlen):** Baue für dich als Entwickler irgendwo in der App (z.B. auf dem Dashboard) einen Button ein, der nur im Debug-Modus sichtbar ist (`if (kDebugMode)`). Über diesen Button kannst du die Testlogik per Klick aufrufen, falls du die Daten während der Entwicklung versehentlich kaputtgemacht hast.
