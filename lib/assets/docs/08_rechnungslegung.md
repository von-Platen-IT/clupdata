# Rechnungslegung

## Übersicht

Mit der Rechnungslegung erstellen Sie **Beiträge für viele Mitglieder auf einmal** –
statt jeden Beitrag einzeln anzulegen. Ein Assistent führt Sie in wenigen Schritten
durch die Auswahl und zeigt vorab genau, welche Beiträge erstellt werden.

Typische Anwendungsfälle:

- „Für alle Mitglieder den Monatsbeitrag für Juni erstellen"
- „Für Max Mustermann die ausstehenden Monate nachbuchen"
- „Alle Mitglieder des Kurses ‚Boxen Erwachsene' abbrechnen"

## Einstieg

Sie erreichen den Assistenten über:

- Menü **Extras → Rechnungserstellung**
- Menü **Erstellen → Rechnungslegung**
- Tastenkürzel laut [Tastenkürzel](22_tastenkuerzel.md)

## Die vier Abrechnungsarten

| Abrechnungsart | Wann verwenden? |
|----------------|-----------------|
| **Nach Zeitperioden** | Regelmäßige Abrechnung: alle Mitglieder mit gültigem Vertrag für einen Monat, ein Quartal oder ein Jahr |
| **Nach einem einzelnen Mitglied** | Nachbuchen für ein Mitglied, z. B. nach Zahlungseingang oder Vertragsbeginn |
| **Nach ausgewählten Mitgliedern** | Gezielte Abrechnung einer Gruppe, z. B. nach Ermäßigung oder Sondervereinbarung |
| **Nach Kursen** | Alle Mitglieder bestimmter Kurse/Vertragsarten abrechnen |

## Schritt-für-Schritt durch den Assistenten

### Schritt 1: Abrechnungsart wählen

Wählen Sie eine der vier Abrechnungsarten. Sie können später jederzeit
zurückgehen und die Auswahl ändern.

### Schritt 2: Auswahl

Je nach Abrechnungsart:

- **Zeitperioden**: Keine weitere Auswahl nötig – alle Mitglieder mit
  gültigem Vertrag werden berücksichtigt.
- **Einzelnes Mitglied**: Suchen Sie das Mitglied über Namen und wählen Sie es aus.
- **Ausgewählte Mitglieder**: Setzen Sie Häkchen bei den gewünschten Mitgliedern.
- **Kurse**: Wählen Sie eine oder mehrere Kurse (Vertragsarten) aus.

### Schritt 3: Zeitraum und Optionen

- **Zeitraum**: Monat, Quartal, Jahr oder ein frei wählbarer Zeitraum
- **Optionen**:
  - *Nur aktive Verträge*: Mitglieder mit abgelaufenem Vertrag werden übersprungen
  - *Nur Mitglieder ohne offene Beiträge*: verhindert Doppelbelastungen
  - **Status nach Erstellung**: „kontiert" (noch nicht versendet) oder „offen" (zahlbar)
- Optional können Sie eine **Bemerkung** hinterlegen, die in der Status-Historie
  gespeichert wird.

### Schritt 4: Vorschau prüfen

Die Vorschau zeigt **genau die Beiträge**, die erstellt werden:

| Spalte | Bedeutung |
|--------|-----------|
| Häkchen | Nur markierte Zeilen werden erstellt |
| Mitglied | Betroffenes Mitglied |
| Kurs/Leistung | Abgerechnete Vertragsart |
| Zeitraum | Abrechnungsperiode (z. B. 06/2026) |
| Betrag | Preis – **klicken Sie darauf, um ihn zu ändern** |
| Hinweis | z. B. „bereits abgerechnet" oder „abweichender Einzelpreis" |

**Wichtig:**
- Zeilen mit dem Hinweis **„bereits abgerechnet"** sind abgewählt – so ist ein
  versehentliches Doppelerstellen ausgeschlossen.
- Sie können einzelne Zeilen abwählen und Beträge anpassen, bevor erstellt wird.

### Schritt 5: Ergebnis

Nach dem Erstellen sehen Sie eine Zusammenfassung (Anzahl, Gesamtbetrag) und
können direkt zu den Beiträgen wechseln.

## Wie funktioniert die Abrechnung im Hintergrund?

- **Abrechnungsrhythmus**: Der Rhythmus der Vertragsart (Leistung) bestimmt, wie
  viele Beiträge ein Zeitraum erzeugt:

  | Laufzeit der Leistung | Erstellte Beiträge |
  |-----------------------|--------------------|
  | monatlich | 1 Beitrag je Monat im Zeitraum |
  | quartalsweise | 1 Beitrag je Quartal |
  | jährlich | 1 Beitrag je Jahr |
  | einmalig | Nur einmal – nie doppelt |

- **Preis**: Es gilt der individuelle Preis des Mitglieds, sonst der Standardpreis
  der Leistung. Der Preis wird als **Snapshot** gespeichert – spätere
  Preisänderungen betreffen den Beitrag nicht.
- **Rechnungsnummer**: Wird automatisch im Format `RE-YYYY-XXXXX` vergeben.
- **Status-Historie**: Jeder erstellte Beitrag bekommt einen ersten Eintrag in der
  Status-Historie.

## Tipps

- Führen Sie die Rechnungslegung immer zu Beginn des Abrechnungszeitraums durch –
  die Vorschau zeigt dann alle offenen Perioden auf einen Blick
- Nutzen Sie im Zweifel immer die **Vorschau**: Sie können nichts kaputtmachen,
  solange Sie nicht auf „Erstellen" klicken
- Bereits erstellte Beiträge werden nie überschrieben oder verändert

## Siehe auch

- [Beiträge](04_beitraege.md) – Verwaltung der erstellten Beiträge
- [Leistungen](03_leistungen.md) – Vertragsarten und Preise festlegen
- [Status-Farben](20_status_farben.md) – Bedeutung der Status

---

*[Screenshot-Platzhalter: Assistent Schritt 1 – Abrechnungsart]*
*[Screenshot-Platzhalter: Vorschau-Tabelle mit abgewählten Zeilen]*
*[Screenshot-Platzhalter: Ergebnis-Zusammenfassung]*
