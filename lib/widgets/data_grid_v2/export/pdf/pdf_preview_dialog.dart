import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/database/database.dart';
import '../../../../features/stammdaten/data/stammdaten_repository.dart';
import 'pdf_exporter.dart';
import 'pdf_template.dart';
import 'pdf_template_registry.dart';
import 'pdf_template_selector.dart';

/// Dialog showing PDF preview with template selection, print and save capabilities.
///
/// This is a stateful widget that allows users to:
/// - Select from available PDF templates
/// - See live preview of the selected template
/// - Print or save the generated PDF
///
/// The dialog receives raw export data and generates the PDF on-the-fly
/// when the template selection changes.
///
/// Example usage:
/// ```dart
/// final exportData = exporter.prepareListExport(
///   controller,
///   title: 'Mitgliederliste',
///   entityName: 'Mitglied',
/// );
///
/// await showDialog(
///   context: context,
///   builder: (_) => PdfPreviewDialog.fromExportData(exportData),
/// );
/// ```
class PdfPreviewDialog extends ConsumerStatefulWidget {
  /// The prepared export data containing raw data and context.
  final PdfExportData exportData;

  /// Optional initial template to use.
  final PdfTemplate? initialTemplate;

  /// Creates a [PdfPreviewDialog] with prepared export data.
  const PdfPreviewDialog({
    super.key,
    required this.exportData,
    this.initialTemplate,
  });

  /// Convenience factory for creating from export data directly.
  factory PdfPreviewDialog.fromExportData(
    PdfExportData exportData, {
    PdfTemplate? initialTemplate,
  }) {
    return PdfPreviewDialog(
      exportData: exportData,
      initialTemplate: initialTemplate,
    );
  }

  @override
  ConsumerState<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends ConsumerState<PdfPreviewDialog> {
  late PdfTemplate _selectedTemplate;
  Uint8List? _pdfData;
  bool _isGenerating = false;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplate =
        widget.initialTemplate ??
        PdfTemplateRegistry.getDefaultFor(
          isDetailView: widget.exportData.isDetailView,
          entityType: widget.exportData.effectiveEntityType,
        );
    _generatePdf();
  }

  /// Generates the PDF with the currently selected template.
  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final pdfBytes = await PdfExporter.generateFromData(
        widget.exportData,
        _selectedTemplate,
      );

      if (mounted) {
        setState(() {
          _pdfData = pdfBytes;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  /// Called when the user selects a different template.
  void _onTemplateChanged(PdfTemplate? template) {
    if (template == null || template == _selectedTemplate) return;

    setState(() {
      _selectedTemplate = template;
    });
    _generatePdf();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 900,
          height: 750,
          child: Column(
            children: [
              // Header with template selector
              _buildHeader(context),
              // Template selector row
              _buildTemplateSelector(context),
              // PDF preview area
              Expanded(child: _buildPreviewArea(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the dialog header with title and close button.
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.exportData.context.title,
                  style: theme.textTheme.titleMedium,
                ),
                if (widget.exportData.isDetailView)
                  Text(
                    'Detailansicht',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (_pdfData != null && !_isGenerating)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt),
              tooltip: 'Als PDF-Datei speichern',
              onPressed: _isSaving ? null : () => _savePdfToFile(context),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Schließen',
          ),
        ],
      ),
    );
  }

  /// Builds the template selector row.
  Widget _buildTemplateSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PdfTemplateSelector(
              selectedTemplate: _selectedTemplate,
              isDetailView: widget.exportData.isDetailView,
              entityType: widget.exportData.effectiveEntityType,
              onChanged: _onTemplateChanged,
            ),
          ),
          const SizedBox(width: 16),
          // Template info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(_selectedTemplate.category),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedTemplate.category.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main preview area.
  Widget _buildPreviewArea(BuildContext context) {
    if (_isGenerating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF wird generiert...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Fehler bei der PDF-Generierung',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfData == null) {
      return const Center(child: Text('PDF wird vorbereitet...'));
    }

    return PdfPreview(
      build: (format) => _pdfData!,
      allowPrinting: true,
      allowSharing: true,
      canChangePageFormat: false,
      canChangeOrientation: false,
      initialPageFormat: PdfPageFormat.a4,
      pdfFileName: _generateFileName(),
      scrollViewDecoration: const BoxDecoration(),
    );
  }

  /// Returns an icon for each template category.
  IconData _getCategoryIcon(PdfTemplateCategory category) {
    switch (category) {
      case PdfTemplateCategory.generic:
        return Icons.table_rows_outlined;
      case PdfTemplateCategory.invoice:
        return Icons.receipt_outlined;
      case PdfTemplateCategory.member:
        return Icons.person_outlined;
      case PdfTemplateCategory.list:
        return Icons.list_alt_outlined;
      case PdfTemplateCategory.detail:
        return Icons.article_outlined;
    }
  }

  /// Saves the current PDF to a user-chosen file location.
  ///
  /// Reads the last export directory from stammdaten (`pfad_export`)
  /// as initial directory, and persists the chosen directory after saving.
  Future<void> _savePdfToFile(BuildContext context) async {
    if (_pdfData == null) return;

    setState(() => _isSaving = true);

    try {
      // Read last export directory from stammdaten
      String? initialDirectory;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        final setting = await repo.getSetting('pfad_export');
        if (setting?.wert != null && setting!.wert!.isNotEmpty) {
          initialDirectory = setting.wert;
        }
      } catch (_) {
        // Ignore errors reading stammdaten — fall back to default
      }

      final fileName = _generateFileName();

      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF-Datei speichern',
        fileName: fileName,
        initialDirectory: initialDirectory,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (filePath == null) {
        // User cancelled
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      // Write PDF bytes to the chosen file
      final file = File(filePath);
      await file.writeAsBytes(_pdfData!);

      // Persist chosen directory for next export
      final chosenDirectory = file.parent.path;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        final existing = await repo.getSetting('pfad_export');
        if (existing != null) {
          await repo.updateSetting(
            existing.copyWith(wert: Value(chosenDirectory)),
          );
        } else {
          await repo.addSetting(
            StammdatenCompanion.insert(
              schluessel: 'pfad_export',
              wert: Value(chosenDirectory),
              typ: 'string',
              kategorie: 'programm',
              bezeichnung: 'Export-Verzeichnis',
            ),
          );
        }
      } catch (_) {
        // Non-critical: saving the preference failed
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF gespeichert: $filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Generates a filename based on title and current date.
  String _generateFileName() {
    final sanitized = widget.exportData.context.title
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final date = DateTime.now().toIso8601String().split('T').first;
    return '${sanitized}_$date.pdf';
  }
}

/// Simplified dialog for direct PDF preview without template selection.
///
/// Use this when you already have a generated PDF and just want to show it.
class SimplePdfPreviewDialog extends ConsumerStatefulWidget {
  /// The PDF document as byte array.
  final Uint8List pdfData;

  /// The title shown in the dialog header.
  final String title;

  /// Creates a [SimplePdfPreviewDialog] with the given [pdfData] and [title].
  const SimplePdfPreviewDialog({
    super.key,
    required this.pdfData,
    required this.title,
  });

  @override
  ConsumerState<SimplePdfPreviewDialog> createState() =>
      _SimplePdfPreviewDialogState();
}

class _SimplePdfPreviewDialogState
    extends ConsumerState<SimplePdfPreviewDialog> {
  bool _isSaving = false;

  /// Saves the PDF to a user-chosen file location.
  Future<void> _savePdfToFile(BuildContext context) async {
    setState(() => _isSaving = true);

    try {
      // Read last export directory from stammdaten
      String? initialDirectory;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        final setting = await repo.getSetting('pfad_export');
        if (setting?.wert != null && setting!.wert!.isNotEmpty) {
          initialDirectory = setting.wert;
        }
      } catch (_) {
        // Ignore errors reading stammdaten — fall back to default
      }

      final fileName = _generateFileName();

      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF-Datei speichern',
        fileName: fileName,
        initialDirectory: initialDirectory,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (filePath == null) {
        // User cancelled
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      // Write PDF bytes to the chosen file
      final file = File(filePath);
      await file.writeAsBytes(widget.pdfData);

      // Persist chosen directory for next export
      final chosenDirectory = file.parent.path;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        final existing = await repo.getSetting('pfad_export');
        if (existing != null) {
          await repo.updateSetting(
            existing.copyWith(wert: Value(chosenDirectory)),
          );
        } else {
          await repo.addSetting(
            StammdatenCompanion.insert(
              schluessel: 'pfad_export',
              wert: Value(chosenDirectory),
              typ: 'string',
              kategorie: 'programm',
              bezeichnung: 'Export-Verzeichnis',
            ),
          );
        }
      } catch (_) {
        // Non-critical: saving the preference failed
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF gespeichert: $filePath'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 800,
          height: 700,
          child: Column(
            children: [
              // Custom header matching app design
              _buildHeader(context),
              // PDF preview
              Expanded(
                child: PdfPreview(
                  build: (format) => widget.pdfData,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: _generateFileName(),
                  scrollViewDecoration: const BoxDecoration(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the dialog header with title and close button.
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.title, style: theme.textTheme.titleMedium),
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            tooltip: 'Als PDF-Datei speichern',
            onPressed: _isSaving ? null : () => _savePdfToFile(context),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Schließen',
          ),
        ],
      ),
    );
  }

  /// Generates a filename based on title and current date.
  String _generateFileName() {
    final sanitized = widget.title
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final date = DateTime.now().toIso8601String().split('T').first;
    return '${sanitized}_$date.pdf';
  }
}
