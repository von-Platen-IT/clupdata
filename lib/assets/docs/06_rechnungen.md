# Rechnungen

## Übersicht

Der Bereich "Rechnungen" dient der Verwaltung von Rechnungen für Warenverkäufe (POS - Point of Sale). Hier können Sie neue Rechnungen erstellen, den Zahlungsstatus verfolgen und Rechnungen bearbeiten.

## Funktionen

### Datenübersicht

Die Rechnungsliste zeigt folgende Informationen:

| Spalte | Beschreibung |
|--------|-------------|
| Rechnungs-Nr. | Eindeutige Rechnungsnummer (Format: R-YYYY-XXXXX) |
| Kunde | Name des Kunden (Mitglied oder Walk-in) |
| Datum | Rechnungsdatum |
| Betrag (€) | Brutto-Gesamtbetrag |
| Status | Zahlungsstatus (farbig hervorgehoben) |

### Status-Farben für Rechnungen

| Status | Farbe | Bedeutung |
|--------|-------|-----------|
| offen | 🟠 Hellorange | Ausstehende Zahlung |
| bezahlt | 🟢 Hellgrün | Bezahlte Rechnung |
| storniert | ⚪ Hellgrau | Stornierte Rechnung |

### Neue Rechnung erstellen

1. Klicken Sie auf das **"+"-Symbol** in der Symbolleiste
2. Füllen Sie die folgenden Felder aus:

#### Kundenangaben
- **Mitglied suchen**: Optional - Mitglied auswählen
- **Kundenname**: Für Walk-in-Kunden (wenn kein Mitglied)
- **Rechnungsdatum**: Datum der Rechnung (Standard: heute)

#### Positionen hinzufügen
- **Artikel suchen**: Suchen Sie nach Waren
- **Menge**: Anzahl der verkauften Artikel
- **Preis**: Wird automatisch übernommen

#### Summen
- **Netto (€)**: Summe der Nettopreise
- **MwSt (€)**: Summe der MwSt
- **Brutto (€)**: Gesamtsumme (fett hervorgehoben)

### Rechnung bearbeiten

1. Wählen Sie eine Rechnung in der Liste aus
2. Doppelklicken Sie auf den Eintrag
3. Ändern Sie die gewünschten Felder:

#### Bereich: Rechnung
- **Status**: Offen, Bezahlt, Storniert
- **Rechnungsdatum**: Datum der Rechnung
- **Fällig am**: Fälligkeitsdatum
- **Bezahlt am**: Zahlungsdatum (nur bei Status=bezahlt)

#### Bereich: Kunde
- **Mitglied**: Optional zuordenbar
- **Kundenname**: Für Nicht-Mitglieder

#### Bereich: Positionen
- **Artikel hinzufügen**: Neue Positionen einfügen
- **Positionen bearbeiten**: Menge/Preis ändern
- **Positionen löschen**: Einzelne Positionen entfernen

### Rechnung löschen

1. Wählen Sie die zu löschende Rechnung aus
2. Klicken Sie auf das **Löschen-Symbol**
3. Bestätigen Sie die Löschung im Dialog

**Hinweis**: Beim Löschen einer Rechnung werden auch alle zugehörigen Positionen gelöscht.

## Tipps

- Entweder **Mitglied ODER Kundenname** muss angegeben sein
- Die Rechnungsnummer wird automatisch generiert
- Preise werden als Snapshot gespeichert
- Die MwSt wird aus den Stammdaten ermittelt

---

*[Screenshot-Platzhalter: Rechnungsliste]*
*[Screenshot-Platzhalter: Neue Rechnung erstellen Dialog]*
*[Screenshot-Platzhalter: Rechnung bearbeiten Dialog]*
