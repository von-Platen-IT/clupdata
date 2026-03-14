# ClupData (Boxing Club App)

Ein Desktop-Verwaltungssystem (Windows/macOS/Linux) für einen Boxclub. Dieses Projekt dient zur effizienten Verwaltung von Mitgliedern, Verträgen und Point-of-Sale (POS) Verkäufen.

## 🚀 Features

- **Mitgliederverwaltung (Members):** Erfassen, Bearbeiten und Verwalten von Club-Mitgliedern.
- **Vertragsverwaltung (Contracts):** Übersicht und Organisation von Mitgliedsverträgen.
- **Beitragsverwaltung (Beiträge):** Verwaltung von Mitgliedsbeiträgen mit Status-Verfolgung.
- **Rechnungslegung:** Massenerstellung von Beiträgen für alle Mitglieder mit gültigem Vertrag.
- **Point-of-Sale (POS):** Integriertes Kassensystem für den Verkauf von Artikeln oder Dienstleistungen.

## 🛠 Tech Stack & Architektur

Die App ist strikt auf Desktop-Nutzung optimiert (Maus & Tastatur) und nutzt modernste Flutter-Technologien nach einem "No-Boilerplate"-Ansatz:

- **Framework:** Flutter (Material 3, Desktop-optimiert)
- **State Management:** [hooks_riverpod](https://pub.dev/packages/hooks_riverpod) / `flutter_hooks` (keine StatefulWidgets)
- **Routing:** [go_router](https://pub.dev/packages/go_router)
- **Database (SQLite ORM):** [drift](https://pub.dev/packages/drift)
- **Data Classes:** [freezed](https://pub.dev/packages/freezed) & [json_serializable](https://pub.dev/packages/json_serializable)

Das Projekt ist **Feature-First** strukturiert (`lib/features/...`), um hohe Skalierbarkeit und Maintainability zu gewährleisten. Die Datenbank-Kommunikation ist strikt in Repositories (Riverpod-Provider) gekapselt.

## 💻 Entwicklung & lokales Setup

### Voraussetzungen
- Flutter SDK aktuell (unterstützt Desktop-Builds für das jeweilige Host-System)
- Code-Generator Tooling aktiv

### Code Generation (Wichtig!)
Dieses Projekt nutzt umfangreiche Code-Generierung (`freezed`, `drift`, `riverpod_generator`). Nach API-Änderungen oder Änderungen an Models/Tabellen muss der Build-Runner ausgeführt werden:

```bash
# Generiert alle *.g.dart, *.freezed.dart und *.drift.dart Dateien
dart run build_runner build -d
```
Für den laufenden Entwicklungsbetrieb kann auch `watch` genutzt werden:
```bash
dart run build_runner watch -d
```

### App starten
Führe das Projekt als Desktop-App für dein System aus (macOS, Windows oder Linux):

```bash
flutter run -d macOS   # bzw. windows / linux
```

## 📐 UI & Design-Richtlinien
- **Desktop-Look:** Kompaktere Darstellung als bei Mobile Apps (reduziertes Padding, kleinere Schriften). Einsatz von Sidebars (`NavigationRail` / Split-Views) und DataTables.
- Keine klassischen Abstände (`SizedBox`), stattdessen wird das [gap](https://pub.dev/packages/gap) Package verwendet.
- Wiederverwendbare Komponenten sind unter `lib/common_widgets/` zu finden.

## 📝 Rechnungslegung

Die **Rechnungslegung** ermöglicht die Massenerstellung von Beiträgen für alle Mitglieder mit gültigem Vertrag.

### Bedienung
1. Menü **"Erstellen"** → **"Rechnungslegung"** auswählen
2. **Jahr** und **Monat** für die Abrechnung wählen
3. Auf **"Speichern"** klicken

### Funktionsweise

**Voraussetzungen für die Erstellung:**
- Mitglied muss eine `leistungId` (Vertragsart) zugeordnet haben
- Für den gewählten Zeitraum darf noch kein Beitrag existieren (Vermeidung von Duplikaten)

**Ablauf der Erstellung:**
- Es werden Beitragseinträge für alle qualifizierten Mitglieder erstellt
- Jeder Beitrag erhält eine eindeutige Rechnungsnummer im Format `RE-YYYY-XXXX`
- Der **Kontierungsdatum** ist immer das aktuelle Datum (wann die Rechnungslegung durchgeführt wurde)
- Der **Abrechnungszeitraum** wird auf den 1. des gewählten Monats gesetzt (zur Duplikat-Prüfung)
- Der Status wird automatisch auf **"kontiert"** gesetzt
- Ein History-Eintrag wird automatisch angelegt

**Preisfindung:**
- Wenn das Mitglied einen individuellen Preis (`preisId`) hat → dieser wird verwendet
- Sonst wird der Preis der zugeordneten Leistung (Vertragsart) verwendet
- Es wird immer ein Preis-Snapshot gespeichert (Preisänderungen haben keine Auswirkung auf bestehende Beiträge)

**Ergebnis:**
- Anzahl der erstellten Beiträge
- Anzahl der übersprungenen Mitglieder (bereits kontiert oder kein Vertrag)
- Liste eventueller Fehler (mitgliedsspezifisch)

---
*Generated & maintained with modern Flutter Best Practices.*
