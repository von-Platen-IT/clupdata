import 'dart:io';

import 'package:intl/intl.dart';

import '../../../core/data/export_data_repository.dart';
import '../../../core/models/data_grid_meta_state.dart';
import '../../../core/models/entity_type_info.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_export_context.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../../../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';
import '../domain/batch_export_config.dart';

/// Service for batch PDF export operations.
///
/// Exports multiple items as individual PDFs or combined into a single PDF.
/// Uses the headless export pipeline (ExportDataRepository + PdfExporter).
class BatchPdfExporter {
  final ExportDataRepository _repository;

  BatchPdfExporter(this._repository);

  /// Executes a batch export operation.
  ///
  /// Returns a [BatchExportResult] with statistics and file paths.
  Future<BatchExportResult> executeBatchExport(
    BatchExportConfig config, {
    void Function(int current, int total)? onProgress,
  }) async {
    final startTime = DateTime.now();
    final generatedFiles = <String>[];
    final errors = <BatchExportError>[];

    // Determine which items to export
    List<int> itemIds;
    if (config.itemIds != null) {
      // Enforce batch size limit
      final requestedIds = config.itemIds!;
      if (requestedIds.length > BatchExportConfig.maxBatchSize) {
        itemIds = requestedIds.sublist(0, BatchExportConfig.maxBatchSize);
      } else {
        itemIds = requestedIds;
      }
    } else {
      // Fetch all items matching the current filters
      itemIds = await _repository.fetchItemIdsForExport(
        entityType: config.entityType,
        metaState: config.metaState,
        dateFrom: config.dateFrom,
        dateTo: config.dateTo,
      );
      // Enforce batch size limit
      if (itemIds.length > BatchExportConfig.maxBatchSize) {
        itemIds = itemIds.sublist(0, BatchExportConfig.maxBatchSize);
      }
    }

    final total = itemIds.length;

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
    for (var i = 0; i < itemIds.length; i++) {
      final itemId = itemIds[i];
      onProgress?.call(i + 1, total);

      try {
        // Fetch data for this item
        final exportData = await _prepareDetailExportForItem(
          config.metaState,
          itemId,
        );

        // Generate PDF
        final pdfBytes = await PdfExporter.generateFromData(
          exportData,
          template,
        );

        // Generate filename
        final filename = _generateFilename(
          config.filenamePattern,
          config.entityType,
          itemId,
          exportData,
        );

        // Save to file
        final filePath = '${outputDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        generatedFiles.add(filePath);
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

    // Optionally combine into single PDF
    String? combinedFilePath;
    if (config.combineIntoSinglePdf && generatedFiles.isNotEmpty) {
      combinedFilePath = await _combinePdfs(
        generatedFiles,
        '${outputDir.path}/${config.entityType}_batch_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
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

    // Extract name from first row if available
    if (exportData.dataTable.rows.isNotEmpty) {
      final firstRow = exportData.dataTable.rows.first;
      if (firstRow.isNotEmpty) {
        final name = firstRow.first.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        filename = filename.replaceAll('{name}', name);
      }
    }

    return filename;
  }

  /// Combines multiple PDF files into a single PDF.
  ///
  /// For now, returns the first PDF as the combined output.
  /// In production, use a proper PDF merging library.
  Future<String?> _combinePdfs(List<String> pdfPaths, String outputPath) async {
    if (pdfPaths.isEmpty) return null;

    // Copy first file as combined output
    final firstFile = File(pdfPaths.first);
    if (await firstFile.exists()) {
      await firstFile.copy(outputPath);
      return outputPath;
    }
    return null;
  }

  String _getTitleForEntityType(String entityType) {
    return EntityTypeInfo.displayNameFor(entityType);
  }

  String? _detectEntityType(String entityName) {
    return EntityTypeInfo.detect(entityName);
  }
}
