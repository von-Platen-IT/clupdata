# Status-Farben

## Übersicht

Die Anwendung verwendet ein konsistentes Farbschema zur visuellen Darstellung von Status-Werten. Diese Farben helfen, den Zustand von Beiträgen und Rechnungen auf einen Blick zu erkennen.

## Beitrags-Status

| Status | Farbe | Hex-Code | Verwendung |
|--------|-------|----------|------------|
| kontiert | 🟡 Hellgelb | `#FFF9C4` | Neu angelegte Beiträge |
| offen | 🟠 Hellorange | `#FFE0B2` | Fällige, ausstehende Zahlungen |
| bezahlt | 🟢 Hellgrün | `#C8E6C9` | Vollständig bezahlte Beiträge |
| angemahnt | 🔴 Hellrot | `#FFCDD2` | Zahlungserinnerung versandt |
| storniert | ⚪ Hellgrau | `#EEEEEE` | Stornierte Rechnungen |
| inkasso | 🩷 Pink | `#F8BBD0` | An Inkasso übergeben |

## Rechnungs-Status

| Status | Farbe | Hex-Code | Verwendung |
|--------|-------|----------|------------|
| offen | 🟠 Hellorange | `#FFE0B2` | Ausstehende Zahlung |
| bezahlt | 🟢 Hellgrün | `#C8E6C9` | Bezahlte Rechnungen |
| storniert | ⚪ Hellgrau | `#EEEEEE` | Stornierte Rechnungen |

## Wo werden die Farben verwendet?

1. **DataGrid-Zeilen**: Jede Zeile erhält die Hintergrundfarbe gemäß ihrem Status
2. **Status-Badge**: Der Status-Text wird als farbiges Badge dargestellt
3. **Edit-Dialog**: Das Status-Dropdown zeigt die Farbe des ausgewählten Werts

## Wichtige Hinweise

- Die Farben sind zentral definiert und dürfen nicht hardcodiert werden
- Änderungen erfordern ein Update der zentralen Farbdefinition

---

*[Screenshot-Platzhalter: Beitragsliste mit farbig markierten Status-Zeilen]*
*[Screenshot-Platzhalter: Status-Badge im Detail]*
