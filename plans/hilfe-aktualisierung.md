# Plan: Online-Hilfe an den aktuellen Stand anpassen

> **Status**: Entwurf
> **Erstellt**: 2026-10-13
> **Betroffen**: [`lib/assets/docs/`](../lib/assets/docs) (15 Markdown-Dokumente), [`documentation_screen.dart`](../lib/features/documentation/documentation_screen.dart:1)

---

## 1. Ziel

Die Online-Hilfe („Hilfe & Dokumentation") wird an den aktuellen Funktionsstand
angepasst, veraltete Inhalte korrigiert und neue Funktionen dokumentiert. Sie soll
**leicht verständlich und praxistauglich** sein und in der Software so abgebildet
werden, dass **neue Benutzer sich schnell einarbeiten** können.

---

## 2. Analyse: Ist-Zustand je Dokument

| # | Dokument | Status | Befund |
|---|----------|--------|--------|
| 00 | [`00_index.md`](../lib/assets/docs/00_index.md) | ⚠️ Teilweise veraltet | **Falscher Produktname** „PhraPhikanet Organizer" (App heißt **ClupData**); neue Themen fehlen; kein Einstieg für Neueinsteiger |
| 01 | [`01_start.md`](../lib/assets/docs/01_start.md) | ⚠️ Teilweise veraltet | Produktname falsch; Navigationstabelle unvollständig (Kursplan-Beschreibung „Terminübersicht" veraltet) |
| 02 | [`02_mitglieder.md`](../lib/assets/docs/02_mitglieder.md) | ✅ Aktuell | Gleiches bewährtes Muster wie 03 – nur Produktname prüfen |
| 03 | [`03_leistungen.md`](../lib/assets/docs/03_leistungen.md) | ✅ Aktuell | Vollständig, praxistauglich (Schritt-für-Schritt, Tabellen, Tipps) |
| 04 | [`04_beitraege.md`](../lib/assets/docs/04_beitraege.md) | ⚠️ Teilweise veraltet | „Erstellen > Rechnungslegung" öffnet jetzt den **Assistenten**, nicht den Beitrag-Dialog; **Rechnungslegung (Wizard, 4 Modi) fehlt komplett** |
| 05 | [`05_waren.md`](../lib/assets/docs/05_waren.md) | ✅ Aktuell | Nur Produktname prüfen |
| 06 | [`06_rechnungen.md`](../lib/assets/docs/06_rechnungen.md) | ✅ Aktuell | POS-Rechnungen korrekt beschrieben |
| 07 | [`07_kursplan.md`](../lib/assets/docs/07_kursplan.md) | ❌ **Komplett veraltet** | Beschreibt Monats-/Tagesansicht und „Termin erstellen"-Dialog – **existiert so nie**; neu: Wochen-Raster, Kurse mit Farben, Kurspläne mit Gültigkeitszeitraum |
| 10 | [`10_datei.md`](../lib/assets/docs/10_datei.md) | ⚠️ Kleinere Veraltungen | Backup-Verzeichnis jetzt im Screen „Sicherung & Wiederherstellung" pflegbar; Backup-Schlüssel ergänzen |
| 11 | [`11_erstellen.md`](../lib/assets/docs/11_erstellen.md) | ⚠️ Veraltet | „Rechnungslegung = Dialog zum Erstellen eines Beitrags" → jetzt **Assistent** (Wizard) |
| 12 | [`12_datenuebertragung.md`](../lib/assets/docs/12_datenuebertragung.md) | ⚠️ Veraltet + Fehler | Backup/Restore jetzt im **eigenen Screen** (Auto-Backup!); **russischer Textfehler** „ранее" (Zeile 27) |
| 13 | [`13_hilfe.md`](../lib/assets/docs/13_hilfe.md) | ✅ Aktuell | Nur Produktname prüfen |
| 20 | [`20_status_farben.md`](../lib/assets/docs/20_status_farben.md) | ✅ Aktuell | Korrekt |
| 21 | [`21_bemerkungen.md`](../lib/assets/docs/21_bemerkungen.md) | ✅ Aktuell | Korrekt |
| 22 | [`22_tastenkuerzel.md`](../lib/assets/docs/22_tastenkuerzel.md) | ⚠️ Unvollständig | Nur ESC/Enter – **Menü-Tastenkürzel fehlen** (z. B. Strg+B Backup) |

### 2.1 Dazugekommen (nicht dokumentiert)

| Funktion | Erschienen durch | Lösung |
|---|---|---|
| **Rechnungslegungs-Assistent** (4 Modi: Zeitperioden, Einzelmitglied, ausgewählte Mitglieder, Kurse; Vorschau; Abrechnungsrhythmus) | [`plans/rechnungsstellung-konzept.md`](rechnungsstellung-konzept.md) | **Neues Dokument** [`08_rechnungslegung.md`](../lib/assets/docs/08_rechnungslegung.md) + Verlinkung aus 04/11 |
| **Kursplan neu** (Wochen-Raster Mo–So mit Uhrzeiten, farbige Kurse, mehrere Pläne mit Gültigkeit, Wochen-Navigation) | [`plans/kursplan.md`](kursplan.md) | [`07_kursplan.md`](../lib/assets/docs/07_kursplan.md) **komplett neu** |
| **Sicherung & Wiederherstellung** (Screen, Auto-Backup beim Start, Intervall in Tagen, Backup-Liste, Restore) | [`plans/backup-konzept.md`](backup-konzept.md) | **Neues Dokument** [`09_sicherung.md`](../lib/assets/docs/09_sicherung.md) + Verlinkung aus 12 |

---

## 3. Redaktionsrichtlinien (leicht verständlich & praxistauglich)

Alle Dokumente folgen dem bewährten Muster von [`03_leistungen.md`](../lib/assets/docs/03_leistungen.md):

1. **Sie-Form**, kurze Sätze, keine Entwicklerbegriffe
2. **Struktur**: Übersicht → Funktionen (Schritt-für-Schritt mit nummerierten Listen) → Tipps
3. **Tabellen** für Felder/Spalten, **fette Hervorhebung** für UI-Texte (Buttons, Menüs)
4. **„Siehe auch"-Verlinkungen** zwischen verwandten Themen
5. **Screenshot-Platzhalter** beibehalten (`*[Screenshot-Platzhalter: …]*`)
6. Produktname durchgängig **ClupData**

---

## 4. Umfang je Dokument

### 4.1 Neue Dokumente

**[`08_rechnungslegung.md`](../lib/assets/docs/08_rechnungslegung.md)** (NEU):
- Übersicht: Was ist die Rechnungslegung? (Beiträge für viele Mitglieder auf einmal)
- Einstieg: Menü Extras → Rechnungserstellung / Erstellen → Rechnungslegung
- **Die vier Modi** (Tabelle: Wofür eignet sich was?):
  Zeitperioden / Einzelnes Mitglied / Ausgewählte Mitglieder / Kurse
- Schritt-für-Schritt durch den Assistenten (Modus → Auswahl → Zeitraum & Optionen → Vorschau → Ergebnis)
- **Vorschau** erklären: Zeilen abwählbar, Betrag änderbar, „bereits abgerechnet" = Schutz vor Doppelbuchung
- Abrechnungsrhythmus (monatlich/quartalsweise/jährlich/einmalig) verständlich erklären
- Häufige Fragen: „Was passiert mit dem Status?" (kontiert/offen), „Was ist mit dem Preis?" (Snapshot)
- Siehe auch: Beiträge, Leistungen

**[`09_sicherung.md`](../lib/assets/docs/09_sicherung.md)** (NEU):
- Übersicht: Warum sichern? (Datenverlust vermeiden)
- **Automatische Datensicherung**: Intervall in Tagen einstellen, Verzeichnis wählen, was passiert beim Programmstart?
- **Manuelle Sicherung**: „Jetzt sichern…" (eigenes Verzeichnis) vs. „In Auto-Verzeichnis sichern"
- **Wiederherstellen**: aus der Liste oder aus Datei – Warnung! (ersetzt alle Daten), Neustart-Hinweis
- Bedeutung der Spalten in der Backup-Liste (Datei, Erstellt am, Größe)
- Tipps: Verzeichnis auf externe Festplatte/Netzlaufwerk legen; Regelmäßigkeit
- Siehe auch: Datenübertragung, Einstellungen

### 4.2 Aktualisierungen

| Dokument | Änderungen |
|---|---|
| `00_index.md` | Produktname → ClupData; Einträge 08/09 ergänzen; **neuer Abschnitt „Erste Schritte für neue Benutzer"** (Reihenfolge: Stammdaten → Leistungen → Mitglieder → Rechnungslegung → Sicherung einrichten) |
| `01_start.md` | Produktname; Navigationstabelle aktualisieren (Kursplan = Wochen-Raster; Hinweis Sicherung) |
| `04_beitraege.md` | Punkt „Neuen Beitrag erstellen": Erstellen-Menü-Hinweis korrigieren (öffnet Assistent, Einzel-Beitrag über „+"); **neuer Abschnitt „Beiträge für viele Mitglieder (Rechnungslegung)"** mit Kurzüberblick + Link zu 08 |
| `07_kursplan.md` | **Komplett neu**: Wochen-Raster, Wochen-Navigation, Plan-Auswahl, Kurse anlegen (mit Farbe), Kurspläne + Gültigkeit, Termine, Legende |
| `10_datei.md` | Backup-Schlüssel unter „Programm" ergänzen; Hinweis, dass das Backup-Verzeichnis auch im Screen „Sicherung & Wiederherstellung" gepflegt wird |
| `11_erstellen.md` | „Rechnungslegung"-Eintrag: jetzt Assistent (Beschreibung + Link zu 08) |
| `12_datenuebertragung.md` | Backup/Restore-Abschnitte auf den **Screen „Sicherung & Wiederherstellung"** umstellen (Auto-Backup erwähnen); russischen Textfehler „ранее" beheben; Link zu 09 |
| `22_tastenkuerzel.md` | Menü-Tastenkürzel aus [`keyboard_shortcuts.dart`](../lib/core/keyboard/keyboard_shortcuts.dart) übernehmen (z. B. Strg+B Backup, Rechnungslegung, Erstellen-Funktionen) |
| `02/05/06/13/20/21` | Nur Produktname-Prüfung (ClupData), keine inhaltlichen Änderungen |

---

## 5. Software-Integration (documentation_screen)

Damit neue Benutzer sich schnell einarbeiten:

1. **Neue Navigationseinträge** im [`DocumentationScreen`](../lib/features/documentation/documentation_screen.dart:94):
   - „Rechnungslegung" (`08_rechnungslegung.md`, Icon: `Icons.receipt_long`) unter **Hauptfunktionen**
   - „Sicherung & Wiederherstellung" (`09_sicherung.md`, Icon: `Icons.settings_backup_restore`) unter **Hauptfunktionen**
2. **Willkommens-Bildschirm erweitern** ([`_buildWelcomeScreen`](../lib/features/documentation/documentation_screen.dart:177)):
   - Abschnitt **„Erste Schritte"** mit Quick-Links: `00_index.md` (Schnellstart), `04_beitraege.md`, `08_rechnungslegung.md`, `09_sicherung.md`
   - Zielgruppe: Neue Nutzer finden den Einstieg ohne zu suchen
3. **Suche**: funktioniert titelbasiert (bereits vorhanden) – neue Einträge sind automatisch durchsuchbar

> Hinweis: Die Markdown-Dateien liegen unter `lib/assets/docs/` und werden über
> `rootBundle` geladen; neue Dateien sind ohne Code-Generierung verfügbar.

---

## 6. Umsetzungsreihenfolge

1. ✅ Analyse (dieser Plan)
2. Neue Dokumente: `08_rechnungslegung.md`, `09_sicherung.md`
3. Kern-Aktualisierungen: `07_kursplan.md` (Neufassung), `04_beitraege.md`, `12_datenuebertragung.md`, `11_erstellen.md`
4. Kleinere Aktualisierungen: `00_index.md`, `01_start.md`, `10_datei.md`, `22_tastenkuerzel.md`
5. Produktname-Prüfung: `02/05/06/13/20/21`
6. Software: Navigationseinträge + Willkommens-Screen im [`DocumentationScreen`](../lib/features/documentation/documentation_screen.dart:1)
7. Verifikation: Pfade/Verlinkungen zwischen den Dokumenten, Konsistenz der UI-Beschreibungen mit der SSOT [`structur.md`](../lib/assets/data/structur.md:1)
