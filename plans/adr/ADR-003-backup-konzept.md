# ADR-003: Backup-Konzept über Stammdaten und Dateisystem (kein Schema-Change)

> **Status**: Vorgeschlagen
> **Datum**: 2026-10-13
> **Betroffen**: `lib/features/backup/`, `lib/core/data/database_backup_service.dart`
> **Kontext**: [`plans/backup-konzept.md`](../backup-konzept.md)

## Kontext

Die Desktop-Anwendung benötigt eine durchdachte Datensicherung: manuelle Backups
mit frei wählbarem Verzeichnis, ein konfigurierbares Intervall (Tage) für
automatische Sicherungen, ein Auto-Backup beim Programmstart (wenn das Intervall
überschritten ist) und einen eigenen, ergonomischen UI-Bereich für Backup &
Restore. Der bestehende [`DatabaseBackupService`](../../lib/core/data/database_backup_service.dart:13)
bietet bereits die technische Basis (WAL-Checkpoint + Datei-Kopie, Restore mit
Sicherheitskopie und Rollback).

## Entscheidungen

1. **Kein Schema-Change**: Konfiguration und Status liegen im bestehenden
   key-value-Store [`stammdaten`](../../lib/assets/data/structur.md:72):
   - `pfad_backup` (existiert) – Zielverzeichnis der automatischen Backups
   - `backup_intervall_tage` (neu, Standard 7)
   - `backup_automatisch_aktiv` (neu, Standard 1)
   - `backup_letztes_datum` (neu, nur programmintern änderbar)
   Neue Schlüssel werden per `getOrCreate` beim ersten Zugriff angelegt –
   keine Migration, keine Schema-Version-Erhöhung.

2. **Backup-Liste = Dateisystem-Scan**: Die Übersicht vorhandener Sicherungen
   liest das Auto-Verzeichnis (`clup_data_backup_*.sqlite`, sortiert nach Datum).
   Keine eigene Protokoll-Tabelle – das Backup einer DB, die ihr eigenes
   Backup-Protokoll enthält, wäre ein Hähnei-Problem und unnötiger Ballast.

3. **Auto-Backup als nicht-blockierender Hintergrund-Task**:
   Start per `postFrameCallback` nach dem ersten gerenderten Frame; reines
   asynchrones Datei-IO (WAL-Checkpoint + Kopie) ohne modal-Dialog. Der Status
   wird dezent über einen eigenen Provider angezeigt. Ein Isolate scheidet aus,
   da der WAL-Checkpoint die Drift-Instanz im Haupt-Isolate benötigt.

4. **Intervall in Tagen** (Desktop-typisch, kein OS-Scheduler nötig): Die Prüfung
   erfolgt beim Programmstart – bei typischer täglicher Nutzung entsteht daraus
   eine zuverlässige Turnus-Sicherung.

5. **Restore ohne automatischen App-Abbruch**: Nach
   [`restore()`](../../lib/core/data/database_backup_service.dart:36) wird der
   [`appDatabaseProvider`](../../lib/core/providers/database_provider.dart:12)
   invalidiert (DB neu öffnen) und ein Neustart-Hinweis angezeigt. Statt
   `exit(0)` – bewusst schonend und deterministisch; ein erzwungener Abbruch
   könnte nicht gespeicherte UI-Zustände gefährden.

6. **Bestehende Dialoge bleiben**: Menü/Tastenkürzel (`Backup`, `Restore`)
   öffnen künftig den neuen Screen bzw. dessen Teil-Dialoge – kein Bruch
   gewohnter Workflows.

## Alternativen

- **Eigene Tabelle `backup_protokoll`**: Mehr Metadaten (Art, Erfolg, Größe),
  aber Hähnei-Problem beim Backup der eigenen Protokolldaten und unnötige
  Migration – abgelehnt (Dateisystem-Scan reicht).
- **OS-Scheduler (cron/Task-Planer)**: Zuverlässiger bei seltener Nutzung, aber
  plattformabhängig und mit Berechtigungsproblemen verbunden – abgelehnt.
- **Isolate für den Hintergrund-Task**: WAL-Checkpoint braucht die DB-Instanz,
  Datei-IO ist bereits nicht blockierend – abgelehnt (Over-Engineering).
- **`exit(0)` nach Restore**: Deterministischer Neustart, aber abrupt; der
  Neustart-Hinweis ist sicherer – abgelehnt.

## Konsequenzen

- **Positiv**: Keine Migration; Config im bewährten Stammdaten-Muster; die
  bestehende Backup-Service-Logik (Checkpoint, Rollback, Dateivalidierung)
  wird unverändert genutzt; Auto-Backup stört die Arbeit nicht.
- **Negativ / Aufwand**: Neues Feature-Verzeichnis `lib/features/backup/` mit
  Screen und Services; Intervall-Prüfung nur beim Start (keine Dauerüberwachung
  im laufenden Betrieb – bewusst, siehe Nr. 4).
- **Neutral**: Dateiname-Format und Restore-Rollback bleiben unverändert;
  Aufbewahrung/Rotation ist ein späterer, separater Ergänzungspunkt.
