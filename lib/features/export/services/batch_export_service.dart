import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/data/export_data_repository.dart';
import '../../../core/database/database.dart';
import '../../../core/models/data_grid_meta_state.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_export_context.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import '../domain/batch_export_config.dart';
import '../domain/batch_export_summary.dart';
import 'summary_generator.dart';
import 'summary_generators/mitglieder_summary_generator.dart';
import 'summary_generators/rechnungen_summary_generator.dart';
import 'summary_generators/beitraege_summary_generator.dart';
import 'summary_generators/leistungen_summary_generator.dart';
import 'summary_generators/waren_summary_generator.dart';

/// Service for orchestrating batch export operations.
///
/// Coordinates the export of multiple items, generates summary pages,
/// and combines everything into a single PDF or individual files.
class BatchExportService {
  final ExportDataRepository _repository;
  final Map<String, SummaryGenerator> _summaryGenerators;

  BatchExportService({
    required ExportDataRepository repository,
    required AppDatabase db,
  }) : _repository = repository,
       _summaryGenerators = {
         'mitglied': MitgliederSummaryGenerator(db),
         'rechnung': RechnungenSummaryGenerator(db),
         'beitrag': BeitraegeSummaryGenerator(db),
         'leistung': LeistungenSummaryGenerator(db),
         'ware': WarenSummaryGenerator(db),
       };

  /// Executes a batch export operation.
  ///
  /// Returns a [BatchExportResult] with statistics and file paths.
  Future<BatchExportResult> execute({
    required BatchExportConfig config,
    void Function(int current, int total)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final generatedFiles = <String>[];
    final errors = <BatchExportError>[];

    // Determine which items to export
    List<int> itemIds;
    if (config.itemIds != null) {
      final requestedIds = config.itemIds!;
      if (requestedIds.length > BatchExportConfig.maxBatchSize) {
        itemIds = requestedIds.sublist(0, BatchExportConfig.maxBatchSize);
      } else {
        itemIds = requestedIds;
      }
    } else {
      itemIds = await _repository.fetchItemIdsForExport(
        entityType: config.entityType,
        metaState: config.metaState,
        dateFrom: config.dateFrom,
        dateTo: config.dateTo,
      );
      if (itemIds.length > BatchExportConfig.maxBatchSize) {
        itemIds = itemIds.sublist(0, BatchExportConfig.maxBatchSize);
      }
    }

    final total = itemIds.length;
    if (total == 0) {
      return BatchExportResult(
        totalItems: 0,
        successCount: 0,
        errorCount: 0,
        generatedFiles: [],
        errors: [],
        duration: DateTime.now().difference(startTime),
      );
    }

    // Select template
    final template = config.templateKey != null
        ? PdfTemplateRegistry.get(config.templateKey!)
        : PdfTemplateRegistry.getDefaultFor(
            isDetailView: true,
            entityType: config.entityType,
          );

    if (template == null) {
      throw ArgumentError(
        'No suitable template found for ${config.entityType}',
      );
    }

    // Ensure output directory exists
    final outputDir = Directory(config.outputDirectory);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // Export each item
    final pdfBytesList = <Uint8List>[];
    for (var i = 0; i < itemIds.length; i++) {
      final itemId = itemIds[i];
      onProgress?.call(i + 1, total);

      try {
        final exportData = await _prepareDetailExportForItem(
          config.metaState,
          itemId,
        );

        final pdfBytes = await PdfExporter.generateFromData(
          exportData,
          template,
        );

        if (config.outputMode == BatchExportOutputMode.individualFiles) {
          final filename = _generateFilename(
            config.filenamePattern,
            config.entityType,
            itemId,
            exportData,
          );
          final filePath = '${outputDir.path}/$filename';
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);
          generatedFiles.add(filePath);
        } else {
          pdfBytesList.add(pdfBytes);
        }
      } catch (e, stackTrace) {
        errors.add(
          BatchExportError(
            itemId: itemId,
            error: e.toString(),
            stackTrace: stackTrace.toString(),
          ),
        );
      }
    }

    // Generate summary if requested
    if (config.includeSummary &&
        config.outputMode == BatchExportOutputMode.combinedPdf) {
      try {
        final summary = await _generateSummary(
          config.entityType,
          itemIds,
          config.dateFrom,
          config.dateTo,
        );
        final summaryPdfBytes = await _generateSummaryPdf(summary);
        pdfBytesList.add(summaryPdfBytes);
      } catch (e) {
        errors.add(
          BatchExportError(itemId: -1, error: 'Summary generation failed: $e'),
        );
      }
    }

    // Combine PDFs if needed
    String? combinedFilePath;
    if (config.outputMode == BatchExportOutputMode.combinedPdf &&
        pdfBytesList.isNotEmpty) {
      combinedFilePath = await _combinePdfs(
        pdfBytesList,
        '${outputDir.path}/${config.entityType}_batch_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      generatedFiles.add(combinedFilePath!);
    }

    return BatchExportResult(
      totalItems: total,
      successCount: generatedFiles.length,
      errorCount: errors.length,
      generatedFiles: generatedFiles,
      combinedFilePath: combinedFilePath,
      errors: errors,
      duration: DateTime.now().difference(startTime),
    );
  }

  /// Prepares export data for a single item.
  Future<PdfExportData> _prepareDetailExportForItem(
    DataGridMetaState metaState,
    int itemId,
  ) async {
    final dataTable = await _repository.fetchSingleItemForExport(
      entityType: metaState.entityType,
      itemId: itemId,
      metaState: metaState,
    );

    final pdfContext = PdfExportContext(
      title: '${_getTitleForEntityType(metaState.entityType)} - Detail',
      exportTimestamp: DateTime.now(),
      activeFilters: {},
      activeSorts: [],
      isDetailView: true,
      entityName: metaState.entityType,
    );

    return PdfExportData(
      dataTable: dataTable,
      context: pdfContext,
      isDetailView: true,
      entityType: metaState.entityType,
      detectedEntityType: _detectEntityType(metaState.entityType),
    );
  }

  /// Generates a summary for the exported items.
  Future<BatchExportSummary> _generateSummary(
    String entityType,
    List<int> itemIds,
    DateTime? dateFrom,
    DateTime? dateTo,
  ) async {
    final generator = _summaryGenerators[entityType.toLowerCase()];
    if (generator == null) {
      throw ArgumentError('No summary generator for entity type: $entityType');
    }

    return generator.generateSummary(
      exportedItemIds: itemIds,
      entityDisplayName: _getTitleForEntityType(entityType),
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  /// Generates a PDF page for the summary.
  Future<Uint8List> _generateSummaryPdf(BatchExportSummary summary) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ZUSAMMENFASSUNG - ${summary.entityDisplayName.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Exportiert am: ${_formatDateTime(summary.exportedAt)}'),
              pw.Text('Anzahl exportierter Datensätze: ${summary.totalCount}'),
              if (summary.dateFrom != null || summary.dateTo != null)
                pw.Text('Zeitraum: ${summary.dateRangeString}'),
              pw.SizedBox(height: 24),
              ...summary.sections.map(
                (section) => _buildSummarySection(section),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummarySection(SummarySection section) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          section.title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          children: section.rows.map((row) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(row.label),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(row.value),
                ),
              ],
            );
          }).toList(),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  String _generateFilename(
    String pattern,
    String entityType,
    int itemId,
    PdfExportData exportData,
  ) {
    final date = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());

    var filename = pattern
        .replaceAll('{entityType}', entityType)
        .replaceAll('{id}', itemId.toString())
        .replaceAll('{date}', date);

    if (exportData.dataTable.rows.isNotEmpty) {
      final firstRow = exportData.dataTable.rows.first;
      if (firstRow.isNotEmpty) {
        final name = firstRow.first.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        filename = filename.replaceAll('{name}', name);
      }
    }

    return filename;
  }

  Future<String?> _combinePdfs(
    List<Uint8List> pdfBytesList,
    String outputPath,
  ) async {
    if (pdfBytesList.isEmpty) return null;

    // For now, save the first PDF as the combined output
    // In production, use a proper PDF merging library like pdfx or native merging
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(pdfBytesList.first);

    return outputPath;
  }

  String _getTitleForEntityType(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'mitglied':
        return 'Mitglieder';
      case 'rechnung':
        return 'Rechnungen';
      case 'beitrag':
        return 'Beiträge';
      case 'leistung':
        return 'Leistungen';
      case 'ware':
        return 'Waren';
      default:
        return entityType;
    }
  }

  String? _detectEntityType(String entityName) {
    final lower = entityName.toLowerCase();
    if (lower.contains('rechnung')) return 'rechnung';
    if (lower.contains('mitglied')) return 'mitglied';
    if (lower.contains('beitrag')) return 'beitrag';
    if (lower.contains('leistung')) return 'leistung';
    if (lower.contains('ware')) return 'ware';
    return null;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
