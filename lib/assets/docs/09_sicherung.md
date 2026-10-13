# Sicherung & Wiederherstellung

## Übersicht

Der Bereich **„Sicherung & Wiederherstellung"** schützt Ihre Daten vor Verlust.
Hier erstellen Sie Datensicherungen (Backups) der Datenbank, stellen sie wieder
her und legen fest, wann automatisch gesichert wird.

Sie finden den Bereich über das Menü (Tastenkürzel laut
[Tastenkürzel](22_tastenkuerzel.md)) oder über die Navigation.

## Automatische Datensicherung

ClupData kann **beim Programmstart automatisch sichern**, ohne Ihre Arbeit zu
unterbrechen:

1. Öffnen Sie **Sicherung & Wiederherstellung**
2. Aktivieren Sie **„Beim Programmstart automatisch sichern"**
3. Geben Sie das **Intervall in Tagen** ein (z. B. `7` = einmal pro Woche)
4. Wählen Sie das **Auto-Verzeichnis** („Ändern…"), in dem die Sicherungen
   abgelegt werden sollen

**Wann wird automatisch gesichert?**
Beim Start von ClupData wird geprüft, ob seit dem letzten Backup mehr Tage
vergangen sind als eingestellt. Nur dann wird im Hintergrund gesichert – das
läuft unsichtbar und stört Sie nicht.

Der Statusbereich oben zeigt Ihnen immer: wann das letzte Backup war, wann das
nächste fällig ist und ob eine Sicherung gerade läuft.

## Manuelle Datensicherung

Zwei Möglichkeiten:

| Aktion | Verwendung |
|--------|------------|
| **Jetzt sichern…** | Sie wählen selbst, wohin die Sicherung gespeichert wird (z. B. USB-Stick, externe Festplatte) |
| **In Auto-Verzeichnis sichern** | Sofortige Sicherung in das konfigurierte Auto-Verzeichnis |

Beide Varianten aktualisieren den Zeitpunkt des letzten Backups.

## Vorhandene Sicherungen

Die Liste zeigt alle Sicherungen im Auto-Verzeichnis:

| Spalte | Bedeutung |
|--------|-----------|
| Datei | Name der Sicherungsdatei (`clup_data_backup_…`) |
| Erstellt am | Zeitpunkt der Sicherung |
| Größe | Dateigröße |
| Aktionen | **Wiederherstellen** |

Über **„Aktualisieren"** (🔄) blenden Sie neu erstellte Sicherungen ein.

## Wiederherstellen (Restore)

Sie können eine Sicherung auf zwei Wegen zurückspielen:

1. **Aus der Liste**: Klicken Sie bei der gewünschten Sicherung auf
   **„Wiederherstellen"**
2. **Aus einer Datei**: Über **„Aus Datei wiederherstellen…"** – z. B. von einem
   USB-Stick

**Achtung – bitte unbedingt beachten:**
- Das Wiederherstellen **ersetzt alle aktuellen Daten** durch die gewählte Sicherung
- Zur Sicherheit wird automatisch eine **Sicherheitskopie** der aktuellen Datenbank
  erstellt
- Nach dem Wiederherstellen starten Sie ClupData bitte **neu**

## Tipps

- Wählen Sie als Auto-Verzeichnis am besten einen Ort **außerhalb** des
  Programmfolders, z. B. `Dokumente/ClupData/Backups` oder ein Netzlaufwerk
- Für besonders wichtige Daten: zusätzlich regelmäßig **„Jetzt sichern…"** auf
  einen USB-Stick verwenden
- Die Sicherungsdateien sind normale Datenbankdateien und können auch von
  technischem Personal geprüft werden
- Je größer die Datenbank, desto länger dauert die Sicherung – sie läuft aber
  immer im Hintergrund

## Siehe auch

- [Datenübertragung](12_datenuebertragung.md) – CSV-Import/Export
- [Einstellungen](10_datei.md) – Weitere Konfigurationen

---

*[Screenshot-Platzhalter: Bereich Sicherung & Wiederherstellung mit Status]*
*[Screenshot-Platzhalter: Backup-Liste]*
*[Screenshot-Platzhalter: Bestätigungsdialog Wiederherstellen]*
