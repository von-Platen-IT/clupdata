# PDF-Export und Druck Konfigurationsanleitung

Diese Anleitung beschreibt, wie Sie in der ClupData-Anwendung benutzerdefinierte PDF-Vorlagen erstellen und konfigurieren können, um Daten aus dem System zu **exportieren** und zu **drucken**.

> **Wichtig:** Die gleichen PDF-Vorlagen werden sowohl für den PDF-Export als auch für den direkten Drucker-Output verwendet. Es gibt keinen Unterschied zwischen "Druck-Vorlagen" und "PDF-Vorlagen".

---

## Inhaltsverzeichnis

1. [Systemübersicht](#1-systemübersicht)
2. [PDF und Druck: Einheitliches System](#2-pdf-und-druck-einheitliches-system)
3. [Template-Auswahl im Preview-Dialog](#3-template-auswahl-im-preview-dialog)
4. [PDF-Vorlagen verstehen](#4-pdf-vorlagen-verstehen)
5. [Vorlagentypen](#5-vorlagentypen)
6. [Vorlagen erstellen](#6-vorlagen-erstellen)
7. [Datenformatierung](#7-datenformatierung)
8. [Beispiele](#8-beispiele)
9. [Fehlerbehebung](#9-fehlerbehebung)

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
                              ┌──────────────────────────┼──────────────────┐
                              │                          │                  │
                              ▼                          ▼                  ▼
                    ┌─────────────────┐      ┌─────────────────┐   ┌───────────────┐
                    │  PDF Datei      │      │  Drucker        │   │  E-Mail       │
                    │  (Speichern)    │      │  (Direktdruck)  │   │  (Anhang)     │
                    └─────────────────┘      └─────────────────┘   └───────────────┘
```

---

## 2. PDF und Druck: Einheitliches System

### 2.1 Ein Template für alles

Die ClupData-Anwendung verwendet **dieselben PDF-Vorlagen** für:

| Funktion | Beschreibung |
|----------|--------------|
| **PDF Export** | Speichern als `.pdf`-Datei auf dem Computer |
| **Drucken** | Direkte Ausgabe auf einem Drucker |
| **Vorschau** | Anzeige vor dem Speichern/Drucken |
| **Teilen** | Versenden per E-Mail oder Messenger |

Das bedeutet: Wenn Sie eine Vorlage konfigurieren, wirkt sich das **automatisch** auf alle Ausgabeformen aus.

### 2.2 Ablauf beim Drucken

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌───────────────┐
│  Benutzer   │───▶│  PDF Vorlage    │───▶│  PDF Dokument   │───▶│  Drucker      │
│  klickt     │    │  wird angewendet│    │  wird erstellt  │    │  (A4-Format)  │
│  "Drucken"  │    │                 │    │                 │    │               │
└─────────────┘    └─────────────────┘    └─────────────────┘    └───────────────┘
```

### 2.3 Warum PDF als Zwischenformat?

**Vorteile dieses Ansatzes:**

1. **Konsistenz** - PDF und Papierausdruck sehen identisch aus
2. **Vorschau** - Benutzer können das Ergebnis vor dem Druck prüfen
3. **Flexibilität** - Gleiches Layout für Datei, Druck und E-Mail
4. **Kompatibilität** - PDF wird von allen Druckern unterstützt

### 2.4 Druck-Dialog

Wenn ein Benutzer "Drucken" auswählt:

1. Die PDF-Vorlage wird auf die Daten angewendet
2. Ein PDF-Dokument wird im Hintergrund erzeugt
3. Der System-Druckdialog öffnet sich mit der PDF-Vorschau
4. Der Benutzer kann Drucker, Papierformat und weitere Optionen wählen
5. Das Dokument wird auf dem ausgewählten Drucker ausgegeben

> **Hinweis:** Das Drucken erfolgt immer im **A4-Format**, da dies vom PDF-Template festgelegt wird.

---

## 3. Template-Auswahl im Preview-Dialog

### 3.1 Übersicht

Die Anwendung bietet einen interaktiven Preview-Dialog mit integrierter Template-Auswahl:

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📄 PDF Vorschau - Mitgliederliste                      [X]          │
├─────────────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────┬─────────────────────────────┐   │
│ │ Vorlage: [Einfache Tabelle ▼]   │  [Allgemein]                │   │
│ └─────────────────────────────────┴─────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [PDF-Vorschau mit ausgewählter Vorlage]                           │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│  [Drucken]  [Speichern]  [Teilen]                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Funktionen

| Feature | Beschreibung |
|---------|--------------|
| **Template-Dropdown** | Auswahl aus allen passenden Vorlagen |
| **Live-Regeneration** | PDF wird sofort neu generiert bei Template-Wechsel |
| **Kontext-Filterung** | Nur geeignete Vorlagen werden angezeigt |
| **Kategorie-Anzeige** | Jede Vorlage zeigt ihre Kategorie (z.B. "Rechnung") |

### 3.3 Filterung der Vorlagen

Die angezeigten Vorlagen werden automatisch gefiltert:

**Nach Export-Typ:**
- **Listen-Export**: Zeigt alle Vorlagen mit `supportsDetailView = true` oder `false`
- **Detail-Export**: Zeigt nur Vorlagen mit `supportsDetailView = true`

**Nach Entitätstyp:**
- **Rechnungen**: Priorisiert Vorlagen mit `supportedEntityTypes = ['rechnung']`
- **Mitglieder**: Priorisiert Vorlagen mit `supportedEntityTypes = ['mitglied']`
- **Allgemein**: Zeigt alle `generic` Vorlagen

### 3.4 Vorlagen-Kategorien

| Kategorie | Icon | Beschreibung |
|-----------|------|--------------|
| Allgemein | ⊞ | Universell einsetzbare Layouts |
| Rechnung | 🧾 | Rechnungen, Angebote, Mahnungen |
| Mitglied | 👤 | Mitglieder-Ausweise, Profile |
| Liste | ☰ | Übersichten, Listen |
| Detail | 📄 | Detail-Ansichten einzelner Datensätze |

---

## 4. PDF-Vorlagen verstehen

### 3.1 Was ist eine PDF-Vorlage?

Eine PDF-Vorlage ist eine Klasse, die definiert:
- **Wie Daten angezeigt werden** (Layout, Farben, Schriftarten)
- **Welche Elemente enthalten sind** (Kopfzeile, Tabelle, Fußzeile, Logos)
- **Für welchen Zweck sie geeignet ist** (Listen oder Detailansicht)
- **Zu welcher Kategorie sie gehört** (Rechnung, Mitglied, etc.)

### 4.2 Vorlagen-Interface

Jede Vorlage implementiert das `PdfTemplate`-Interface:

| Eigenschaft | Beschreibung |
|-------------|--------------|
| `displayName` | Deutscher Name in der Auswahlliste |
| `supportsDetailView` | Unterstützt diese Vorlage Detail-Exports? |
| `category` | Kategorie für Filterung und Gruppierung |
| `supportedEntityTypes` | Für welche Entitäten geeignet (z.B. 'rechnung') |
| `generate()` | Methode zur Erzeugung des PDF-Dokuments |

**Beispiel:**
```dart
class InvoicePdfTemplate implements PdfTemplate {
  @override
  String get displayName => 'Rechnungs-Layout';

  @override
  bool get supportsDetailView => true;

  @override
  PdfTemplateCategory get category => PdfTemplateCategory.invoice;

  @override
  List<String>? get supportedEntityTypes => ['rechnung'];

  @override
  Future<pw.Document> generate(
    ExportDataTable dataTable,
    PdfExportContext context,
  ) async {
    // ... Implementierung
  }
}
```

### 4.3 Export-Kontext

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

## 5. Vorlagentypen

### 5.1 Einfache Tabelle (`SimpleTableTemplate`)

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

### 5.2 Kompakte Tabelle (`CompactTableTemplate`)

Eine platzsparende Vorlage für maximale Datendichte auf DIN-A4-Seiten.

**Merkmale:**
- Kleinere Schriftarten (7-8pt statt 10-12pt)
- Minimale Ränder (32pt statt 48pt)
- Kompakte Zeilenhöhen (14-18pt)
- Numerische Werte werden rechtsbündig ausgerichtet
- Zeilenweise Hintergrundfarbe für Lesbarkeit
- Dynamische Spaltenbreiten basierend auf Inhalt

**Verwendung:**
- Listen mit vielen Spalten
- Detaillierte Berichte
- Wenn Platz effizient genutzt werden muss

**Vorteile:**
- Ca. 30-40% mehr Daten pro Seite
- Bessere Übersicht bei breiten Tabellen
- Weniger Seiten beim Drucken

**Layout:**
```
┌────────────────────────────────────────────────────────────────┐
│ Mitgliederliste                              24.03.2026        │
│ Filter: Status: Aktiv | Sort: Name ↑                           │
├────────────────────────────────────────────────────────────────┤
│Name   │Vorname │Status │E-Mail              │Telefon    │Betrag│
├────────────────────────────────────────────────────────────────┤
│Müller │Hans    │Aktiv  │hans@example.com    │0123/456789│120,00│
│Schmidt│Anna    │Aktiv  │anna@example.com    │0123/987654│ 85,00│
└────────────────────────────────────────────────────────────────┘
│ 25 Datensätze                          Seite 1/2               │
└────────────────────────────────────────────────────────────────┘
```

### 5.3 Rechnungsvorlage (`InvoicePdfTemplate`)

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

## 5. Vorlagen erstellen

### 5.1 Neue Vorlage registrieren

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

### 5.2 Layout-Elemente

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

### 5.3 Kopf- und Fußzeilen

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

## 6. Datenformatierung

### 6.1 Datum formatieren

Verwenden Sie deutsche Datumsformate:

```dart
// Über den PdfExportContext
String date = context.formattedDate;        // "24.03.2026"
String datetime = context.formattedTimestamp; // "24.03.2026 14:30"
```

### 6.2 Währungsformatierung

Formatieren Sie Beträge im deutschen Stil:

```dart
String formatCurrency(double amount) {
  return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
}
// Ergebnis: "1.234,56 €"
```

### 6.3 Daten aus ExportDataTable lesen

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

### 6.4 Filter- und Sortierinformationen

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

## 7. Beispiele

### 7.1 Einfache Mitgliederliste

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

### 7.2 Mitglieder-Ausweis (Detail-Export)

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

## 8. Fehlerbehebung

### 8.1 Häufige Fehler

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

### 8.2 Debug-Tipps

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

### 8.3 Best Practices

| ✅ Richtig | ❌ Falsch |
|-----------|-----------|
| Verwenden Sie `const pw.EdgeInsets.all(12)` | Keine magischen Zahlen ohne Konstanten |
| Prüfen Sie `context.isDetailView` bei Detail-Vorlagen | Annehmen, dass immer Detail-Daten vorhanden sind |
| Verwenden Sie `?? '-'` für optionale Felder | Direkter Zugriff auf möglicherweise null-Werte |
| Definieren Sie wiederverwendbare Stile | Inline-Stile wiederholen |
| Verwenden Sie aussagekräftige Namen für Vorlagen | Unklare Namen wie "Template1" |
| Dokumentieren Sie Ihre Vorlage | Keine Beschreibung oder Beispiele |

---

## 9. Zusammenfassung

### Schnellstart-Checkliste

- [ ] Neue Dart-Datei unter `lib/widgets/data_grid_v2/export/templates/` erstellen
- [ ] `PdfTemplate`-Interface implementieren
- [ ] `displayName`, `supportsDetailView` und `generate()` definieren
- [ ] Layout mit `pw.MultiPage` oder `pw.Page` erstellen
- [ ] Schriftart laden mit `_loadFont()`
- [ ] Vorlage in `PdfTemplateRegistry.register()` registrieren
- [ ] **Testen als PDF-Export** und **als Druck**
- [ ] Papierformat A4 und Seitenränder prüfen

### Druck-spezifische Hinweise

| Aspekt | Hinweis |
|--------|---------|
| **Papierformat** | Immer A4 (`PdfPageFormat.a4`) verwenden |
| **Seitenränder** | Mindestens 48pt (ca. 1,7cm) für Druckersicherheit |
| **Schriftgröße** | Mindestens 8pt für Lesbarkeit |
| **Kontrast** | Ausreichender Kontrast für Schwarz-Weiß-Druck |
| **Seitenumbruch** | `pw.MultiPage` für automatische Paginierung verwenden |

> **Wichtig:** Testen Sie neue Vorlagen immer auf einem echten Drucker oder mit der Druckvorschau, da Bildschirm- und Papierausgabe sich unterscheiden können.

### Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| `lib/widgets/data_grid_v2/export/pdf/pdf_template.dart` | Interface-Definition mit Category |
| `lib/widgets/data_grid_v2/export/pdf/pdf_export_context.dart` | Kontext-Klasse |
| `lib/widgets/data_grid_v2/export/pdf/pdf_template_registry.dart` | Template-Registry mit Filterung |
| `lib/widgets/data_grid_v2/export/pdf/pdf_template_selector.dart` | Template-Auswahl-Dropdown |
| `lib/widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart` | Preview-Dialog mit Live-Regeneration |
| `lib/widgets/data_grid_v2/export/pdf/pdf_exporter.dart` | Export-Logik mit `prepareExport()` |
| `lib/widgets/data_grid_v2/export/export_data_table.dart` | Daten-DTO |
| `lib/widgets/data_grid_v2/export/templates/` | Vorlagen-Verzeichnis |

---

*Dokumentation erstellt für ClupData PDF-Export System v2.0 (mit Template-Auswahl)*
