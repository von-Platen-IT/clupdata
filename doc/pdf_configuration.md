# PDF-Export Konfigurationsanleitung

Diese Anleitung beschreibt, wie Sie in der ClupData-Anwendung benutzerdefinierte PDF-Vorlagen erstellen und konfigurieren können, um Daten aus dem System zu exportieren.

---

## Inhaltsverzeichnis

1. [Systemübersicht](#1-systemübersicht)
2. [PDF-Vorlagen verstehen](#2-pdf-vorlagen-verstehen)
3. [Vorlagentypen](#3-vorlagentypen)
4. [Vorlagen erstellen](#4-vorlagen-erstellen)
5. [Datenformatierung](#5-datenformatierung)
6. [Beispiele](#6-beispiele)
7. [Fehlerbehebung](#7-fehlerbehebung)

---

## 1. Systemübersicht

Das PDF-Export-System der ClupData-Anwendung basiert auf einem modularen Template-System. Es ermöglicht die Erstellung von PDF-Dokumenten in zwei Hauptmodi:

### 1.1 Listen-Export
Exportiert alle aktuell sichtbaren Datensätze aus einer Tabelle (z.B. die gefilterte Mitgliederliste).

### 1.2 Detail-Export
Exportiert einen einzelnen Datensatz mit allen Details (z.B. eine einzelne Rechnung oder ein Mitglied).

### 1.3 Architektur

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  DataGrid Daten │────▶│  ExportDataTable│────▶│  PDF Template   │
│  (Modelle)      │     │  (formatiert)   │     │  (Layout)       │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
                                               ┌─────────────────┐
                                               │  PDF Dokument   │
                                               └─────────────────┘
```

---

## 2. PDF-Vorlagen verstehen

### 2.1 Was ist eine PDF-Vorlage?

Eine PDF-Vorlage ist eine Klasse, die definiert:
- **Wie Daten angezeigt werden** (Layout, Farben, Schriftarten)
- **Welche Elemente enthalten sind** (Kopfzeile, Tabelle, Fußzeile, Logos)
- **Für welchen Zweck sie geeignet ist** (Listen oder Detailansicht)

### 2.2 Vorlagen-Interface

Jede Vorlage implementiert das `PdfTemplate`-Interface:

| Eigenschaft | Beschreibung |
|-------------|--------------|
| `displayName` | Name der Vorlage in der Auswahlliste |
| `supportsDetailView` | Unterstützt diese Vorlage Detail-Exports? |
| `generate()` | Methode zur Erzeugung des PDF-Dokuments |

### 2.3 Export-Kontext

Der `PdfExportContext` enthält Metadaten zum Export:

| Feld | Beschreibung | Beispiel |
|------|--------------|----------|
| `title` | Titel des Exports | "Mitgliederliste" |
| `exportTimestamp` | Zeitpunkt des Exports | 24.03.2026 14:30 |
| `activeFilters` | Aktive Filter | {"Status": "Aktiv"} |
| `activeSorts` | Aktive Sortierung | ["Name ↑", "Datum ↓"] |
| `isDetailView` | Detail- oder Listenmodus | true/false |
| `entityName` | Entitätstyp | "Mitglied", "Rechnung" |

---

## 3. Vorlagentypen

### 3.1 Einfache Tabelle (`SimpleTableTemplate`)

Die Standardvorlage für schnelle Datenexporte.

**Merkmale:**
- Klare, übersichtliche Tabellendarstellung
- Automatische Seitenumbrüche
- Abwechselnde Zeilenfarben für bessere Lesbarkeit
- Kopfzeile mit Titel und Filter/Sortier-Informationen
- Fußzeile mit Zeitstempel und Seitenzahlen

**Verwendung:**
- Listen-Exporte aller Art
- Schnelle Datenausgaben
- Archivierungszwecke

**Layout:**
```
┌──────────────────────────────────────┐
│ Mitgliederliste                      │  ← Titel
│ Filter: Status: Aktiv                │  ← Filter
│ Sortierung: Name ↑                   │  ← Sortierung
├──────────────────────────────────────┤
│ Name      │ Vorname   │ Status       │  ← Tabellenkopf
├──────────────────────────────────────┤
│ Müller    │ Hans      │ Aktiv        │  ← Datensätze
│ Schmidt   │ Anna      │ Aktiv        │
└──────────────────────────────────────┘
│ Erstellt: 24.03.2026  Seite 1/3      │  ← Fußzeile
└──────────────────────────────────────┘
```

### 3.2 Rechnungsvorlage (`InvoicePdfTemplate`)

Eine spezialisierte Vorlage für Rechnungen.

**Merkmale:**
- Briefkopf mit Firmenlogo und Adresse
- Rechnungsinformationen (Nummer, Datum, Kunde)
- Positionstabelle mit Artikeln/Leistungen
- Summenbereich (Zwischensumme, MwSt, Gesamtbetrag)
- Fußzeile mit Bankdaten und rechtlichem Hinweis

**Verwendung:**
- Rechnungsausgabe
- Mahnungen
- Angebote

**Layout:**
```
┌──────────────────────────────────────┐
│ [Logo]  Firmenname                   │  ← Briefkopf
│         Musterstraße 1               │
│         12345 Musterstadt            │
├──────────────────────────────────────┤
│ Rechnungsnummer: R-2026-001          │  ← Rechnungsinfo
│ Datum: 24.03.2026                    │
│ Kunde: Max Mustermann                │
├──────────────────────────────────────┤
│ Pos │ Beschreibung      │ Betrag     │  ← Positionen
├──────────────────────────────────────┤
│ 1   │ Mitgliedsbeitrag  │ 120,00 €   │
│ 2   │ Kursgebühr        │ 45,00 €    │
├──────────────────────────────────────┤
│ Zwischensumme:         165,00 €      │  ← Summen
│ MwSt (19%):             31,35 €      │
│ Gesamtbetrag:          196,35 €      │
├──────────────────────────────────────┤
│ Bank: DE12 3456 7890 1234 5678 90    │  ← Fußzeile
│ USt-IdNr.: DE123456789               │
└──────────────────────────────────────┘
```

---

## 4. Vorlagen erstellen

### 4.1 Neue Vorlage registrieren

Um eine neue Vorlage zu erstellen, müssen Sie eine Dart-Datei im Projekt anlegen und die Vorlage im `PdfTemplateRegistry` registrieren.

**Schritt 1: Vorlagendatei erstellen**

Erstellen Sie eine neue Datei unter:
```
lib/widgets/data_grid_v2/export/templates/ihre_vorlage.dart
```

**Schritt 2: Vorlagenklasse implementieren**

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../export_data_table.dart';
import '../pdf/pdf_export_context.dart';
import '../pdf/pdf_template.dart';

/// Beschreibung Ihrer Vorlage
class IhreVorlage implements PdfTemplate {
  // Konfigurationsparameter
  final String companyName;
  final String companyAddress;
  
  const IhreVorlage({
    required this.companyName,
    required this.companyAddress,
  });

  @override
  String get displayName => 'Name in der Auswahlliste';

  @override
  bool get supportsDetailView => true; // oder false

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        header: (format) => _buildHeader(context, font),
        footer: (pwContext) => _buildFooter(context, pwContext, font),
        build: (pwContext) => _buildContent(dataTable, font),
      ),
    );

    return pdf;
  }

  // Hilfsmethoden...
}
```

**Schritt 3: Vorlage registrieren**

Fügen Sie in Ihrer Feature-Initialisierung oder `main.dart` hinzu:

```dart
import 'widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import 'widgets/data_grid_v2/export/templates/ihre_vorlage.dart';

void registerTemplates() {
  PdfTemplateRegistry.register(
    'ihre_vorlage_key',
    IhreVorlage(
      companyName: 'Ihr Verein',
      companyAddress: 'Musterstraße 1\n12345 Musterstadt',
    ),
  );
}
```

### 4.2 Layout-Elemente

#### Seiteneinrichtung

```dart
pw.MultiPage(
  pageFormat: PdfPageFormat.a4,           // A4-Format
  margin: const pw.EdgeInsets.all(48),    // 48pt = ca. 1,7cm Rand
  orientation: pw.PageOrientation.portrait, // oder .landscape
  // ...
)
```

#### Textstile

```dart
final titleStyle = pw.TextStyle(
  font: font,
  fontSize: 16,
  fontWeight: pw.FontWeight.bold,
  color: PdfColors.black,
);

final bodyStyle = pw.TextStyle(
  font: font,
  fontSize: 10,
  color: PdfColors.grey700,
);
```

#### Container und Layout

```dart
pw.Container(
  padding: const pw.EdgeInsets.all(12),
  margin: const pw.EdgeInsets.only(bottom: 20),
  decoration: pw.BoxDecoration(
    color: PdfColors.grey100,
    border: pw.Border.all(color: PdfColors.grey300),
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
  ),
  child: pw.Text('Inhalt', style: bodyStyle),
)
```

#### Spaltenlayout

```dart
pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Expanded(
      flex: 2,
      child: pw.Text('Linke Spalte (2/3)'),
    ),
    pw.Expanded(
      flex: 1,
      child: pw.Text('Rechte Spalte (1/3)'),
    ),
  ],
)
```

#### Tabellen

```dart
pw.Table.fromTextArray(
  headers: dataTable.headers,
  data: dataTable.rows,
  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
  oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
  border: pw.TableBorder.all(color: PdfColors.grey300),
)
```

### 4.3 Kopf- und Fußzeilen

#### Kopfzeile mit Titel

```dart
pw.Widget _buildHeader(PdfExportContext context, pw.Font font) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(context.title, style: titleStyle),
      if (context.filterDescription != null)
        pw.Text('Filter: ${context.filterDescription}', style: metaStyle),
      pw.SizedBox(height: 12),
      pw.Divider(height: 1, thickness: 0.5),
    ],
  );
}
```

#### Fußzeile mit Seitenzahlen

```dart
pw.Widget _buildFooter(
  PdfExportContext context,
  pw.Context pwContext,
  pw.Font font,
) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(context.formattedTimestamp, style: footerStyle),
      pw.Text('Seite ${pwContext.pageNumber}/${pwContext.pagesCount}', 
        style: footerStyle),
    ],
  );
}
```

---

## 5. Datenformatierung

### 5.1 Datum formatieren

Verwenden Sie deutsche Datumsformate:

```dart
// Über den PdfExportContext
String date = context.formattedDate;        // "24.03.2026"
String datetime = context.formattedTimestamp; // "24.03.2026 14:30"
```

### 5.2 Währungsformatierung

Formatieren Sie Beträge im deutschen Stil:

```dart
String formatCurrency(double amount) {
  return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
}
// Ergebnis: "1.234,56 €"
```

### 5.3 Daten aus ExportDataTable lesen

**Als Liste (Listen-Export):**

```dart
// Alle Zeilen durchlaufen
for (final row in dataTable.rows) {
  // row ist eine List<String>
  final name = row[0];  // Erste Spalte
  final value = row[1]; // Zweite Spalte
}
```

**Als Feld-Map (Detail-Export):**

```dart
// Konvertiere zu Map für einfachen Zugriff
Map<String, String> fields = {};
for (final row in dataTable.rows) {
  if (row.length >= 2) {
    fields[row[0]] = row[1];  // Feldname -> Wert
  }
}

// Zugriff über Feldnamen
final name = fields['Name'];
final datum = fields['Datum'];
```

### 5.4 Filter- und Sortierinformationen

```dart
// Filter-Beschreibung
if (context.filterDescription != null) {
  print('Aktive Filter: ${context.filterDescription}');
  // Ausgabe: "Status: Aktiv, Betrag > 100"
}

// Sortier-Beschreibung
if (context.sortDescription != null) {
  print('Sortierung: ${context.sortDescription}');
  // Ausgabe: "Name ↑, Datum ↓"
}
```

---

## 6. Beispiele

### 6.1 Einfache Mitgliederliste

```dart
class MitgliedListeTemplate implements PdfTemplate {
  @override
  String get displayName => 'Mitglieder-Liste';

  @override
  bool get supportsDetailView => true;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        header: (format) => _buildHeader(context, font),
        footer: (pwContext) => _buildFooter(context, pwContext, font),
        build: (pwContext) => [
          pw.Table.fromTextArray(
            headers: dataTable.headers,
            data: dataTable.rows,
            headerStyle: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(PdfExportContext context, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          context.title,
          style: pw.TextStyle(
            font: font,
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Stand: ${context.formattedDate}',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildFooter(
    PdfExportContext context,
    pw.Context pwContext,
    pw.Font font,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          context.title,
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
        pw.Text(
          'Seite ${pwContext.pageNumber} von ${pwContext.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      ],
    );
  }

  Future<pw.Font> _loadFont() async {
    return pw.Font.helvetica();
  }
}
```

### 6.2 Mitglieder-Ausweis (Detail-Export)

```dart
class MitgliedAusweisTemplate implements PdfTemplate {
  final String vereinName;
  final String vereinAdresse;

  const MitgliedAusweisTemplate({
    required this.vereinName,
    required this.vereinAdresse,
  });

  @override
  String get displayName => 'Mitgliedsausweis';

  @override
  bool get supportsDetailView => true;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    if (!context.isDetailView) {
      throw UnsupportedError(
        'Diese Vorlage ist nur für Detail-Exports geeignet.',
      );
    }

    final pdf = pw.Document();
    final font = await _loadFont();
    final fields = _buildFieldMap(dataTable);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (pwContext) => pw.Center(
          child: pw.Container(
            width: 400,
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  vereinName,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  vereinAdresse,
                  style: pw.TextStyle(font: font, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 24),
                pw.Divider(color: PdfColors.black),
                pw.SizedBox(height: 24),
                pw.Text(
                  'MITGLIEDSAUSWEIS',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 24),
                _buildInfoRow('Name:', fields['name'] ?? '-', font),
                _buildInfoRow('Vorname:', fields['vorname'] ?? '-', font),
                _buildInfoRow('Mitgliedsnr.:', fields['mitgliedsnummer'] ?? '-', font),
                _buildInfoRow('Gültig bis:', fields['gueltig_bis'] ?? '-', font),
              ],
            ),
          ),
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildInfoRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _buildFieldMap(ExportDataTable dataTable) {
    final map = <String, String>{};
    for (final row in dataTable.rows) {
      if (row.length >= 2) {
        map[row[0].toLowerCase().trim()] = row[1];
      }
    }
    return map;
  }

  Future<pw.Font> _loadFont() async {
    return pw.Font.helvetica();
  }
}
```

### 6.3 Kombinierte Liste mit Details (z.B. für Mahnungen)

```dart
class MahnungListeTemplate implements PdfTemplate {
  final String companyName;

  const MahnungListeTemplate({required this.companyName});

  @override
  String get displayName => 'Mahnungsliste';

  @override
  bool get supportsDetailView => false;

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        header: (format) => _buildHeader(context, font),
        build: (pwContext) => [
          // Überschrift
          pw.Text(
            'Offene Posten - Mahnlauf',
            style: pw.TextStyle(
              font: font,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          
          // Datentabelle
          pw.Table.fromTextArray(
            headers: dataTable.headers,
            data: dataTable.rows,
            headerStyle: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
          ),
          
          pw.SizedBox(height: 24),
          
          // Zusammenfassung
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red),
            ),
            child: pw.Text(
              'Bitte begleichen Sie die offenen Posten umgehend.',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
        ],
        footer: (pwContext) => _buildFooter(context, pwContext, font),
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(PdfExportContext context, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          companyName,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Divider(height: 1, thickness: 0.5),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildFooter(
    PdfExportContext context,
    pw.Context pwContext,
    pw.Font font,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Vertraulich',
          style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          'Seite ${pwContext.pageNumber}/${pwContext.pagesCount}',
          style: pw.TextStyle(font: font, fontSize: 8),
        ),
      ],
    );
  }

  Future<pw.Font> _loadFont() async {
    return pw.Font.helvetica();
  }
}
```

---

## 7. Fehlerbehebung

### 7.1 Häufige Fehler

#### "UnsupportedError: Template requires detail view"

**Ursache:** Eine Detail-Vorlage wird für einen Listen-Export verwendet.

**Lösung:**
- Prüfen Sie, ob `supportsDetailView` korrekt gesetzt ist
- Stellen Sie sicher, dass der Export im Detail-Dialog durchgeführt wird

#### "Null check operator used on a null value"

**Ursache:** Zugriff auf ein nicht vorhandenes Feld in der Daten-Tabelle.

**Lösung:**
```dart
// Statt:
final value = fields['nicht_vorhanden'];

// Besser:
final value = fields['nicht_vorhanden'] ?? '-';
// oder
final value = fields.containsKey('feld') ? fields['feld'] : '-';
```

#### Schriftart wird nicht angezeigt

**Ursache:** PDF-Paket benötigt explizite Schriftarten.

**Lösung:**
```dart
Future<pw.Font> _loadFont() async {
  // Standard-Schriftart
  return pw.Font.helvetica();
  
  // Oder benutzerdefinierte Schriftart laden:
  // final fontData = await rootBundle.load('assets/fonts/Roboto.ttf');
  // return pw.Font.ttf(fontData);
}
```

### 7.2 Debug-Tipps

#### Daten überprüfen

Fügen Sie temporäres Logging hinzu:

```dart
@override
Future<pw.Document> generate(
  ExportDataTable dataTable,
  PdfExportContext context,
) async {
  // Debug-Ausgabe
  print('Headers: ${dataTable.headers}');
  print('Row count: ${dataTable.rowCount}');
  print('Context title: ${context.title}');
  print('Is detail view: ${context.isDetailView}');
  
  // ... restliche Implementierung
}
```

#### PDF in Datei speichern (Testing)

```dart
// Für Testzwecke können Sie das PDF direkt speichern:
final pdfBytes = await document.save();
final file = File('test_output.pdf');
await file.writeAsBytes(pdfBytes);
print('PDF gespeichert unter: ${file.absolute.path}');
```

### 7.3 Best Practices

| ✅ Richtig | ❌ Falsch |
|-----------|-----------|
| Verwenden Sie `const pw.EdgeInsets.all(12)` | Keine magischen Zahlen ohne Konstanten |
| Prüfen Sie `context.isDetailView` bei Detail-Vorlagen | Annehmen, dass immer Detail-Daten vorhanden sind |
| Verwenden Sie `?? '-'` für optionale Felder | Direkter Zugriff auf möglicherweise null-Werte |
| Definieren Sie wiederverwendbare Stile | Inline-Stile wiederholen |
| Verwenden Sie aussagekräftige Namen für Vorlagen | Unklare Namen wie "Template1" |
| Dokumentieren Sie Ihre Vorlage | Keine Beschreibung oder Beispiele |

---

## 8. Zusammenfassung

### Schnellstart-Checkliste

- [ ] Neue Dart-Datei unter `lib/widgets/data_grid_v2/export/templates/` erstellen
- [ ] `PdfTemplate`-Interface implementieren
- [ ] `displayName`, `supportsDetailView` und `generate()` definieren
- [ ] Layout mit `pw.MultiPage` oder `pw.Page` erstellen
- [ ] Schriftart laden mit `_loadFont()`
- [ ] Vorlage in `PdfTemplateRegistry.register()` registrieren
- [ ] Testen mit verschiedenen Daten

### Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| `lib/widgets/data_grid_v2/export/pdf/pdf_template.dart` | Interface-Definition |
| `lib/widgets/data_grid_v2/export/pdf/pdf_export_context.dart` | Kontext-Klasse |
| `lib/widgets/data_grid_v2/export/pdf/pdf_template_registry.dart` | Template-Registry |
| `lib/widgets/data_grid_v2/export/export_data_table.dart` | Daten-DTO |
| `lib/widgets/data_grid_v2/export/templates/` | Vorlagen-Verzeichnis |

---

*Dokumentation erstellt für ClupData PDF-Export System v1.0*
