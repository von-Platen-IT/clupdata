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

/// Dialog showing a PDF preview with "Exportieren" and "Abbrechen" buttons.
///
/// Simplified dialog that:
/// - Shows a PDF preview of the generated document
/// - Offers "Exportieren" (save to file) and "Abbrechen" (close) buttons
/// - Uses the default template automatically (no template selection)
///
/// Example usage:
/// ```dart
/// await showDialog(
///   context: context,
///   builder: (_) => PdfPreviewDialog(exportData: exportData),
/// );
/// ```
class PdfPreviewDialog extends ConsumerStatefulWidget {
  /// The prepared export data containing raw data and context.
  final PdfExportData exportData;

  /// Optional initial template to use (overrides default).
  final PdfTemplate? initialTemplate;

  const PdfPreviewDialog({
    super.key,
    required this.exportData,
    this.initialTemplate,
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 900,
          height: 750,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.exportData.context.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Schließen',
                    ),
                  ],
                ),
              ),

              // ── Preview area ───────────────────────────────────────
              Expanded(child: _buildPreviewArea(context)),

              // ── Action bar ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed:
                          _pdfData != null && !_isGenerating && !_isSaving
                          ? () => _savePdfToFile(context)
                          : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      label: const Text('Exportieren'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      allowPrinting: false,
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      initialPageFormat: PdfPageFormat.a4,
      pdfFileName: _generateFileName(),
      scrollViewDecoration: const BoxDecoration(),
    );
  }

  Future<void> _savePdfToFile(BuildContext context) async {
    if (_pdfData == null) return;

    setState(() => _isSaving = true);

    try {
      String? initialDirectory;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        final setting = await repo.getSetting('pfad_export');
        if (setting?.wert != null && setting!.wert!.isNotEmpty) {
          initialDirectory = setting.wert;
        }
      } catch (_) {}

      final fileName = _generateFileName();

      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF-Datei speichern',
        fileName: fileName,
        initialDirectory: initialDirectory,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (filePath == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

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
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
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

  String _generateFileName() {
    final sanitized = widget.exportData.context.title
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final date = DateTime.now().toIso8601String().split('T').first;
    return '${sanitized}_$date.pdf';
  }
}

/// Simplified dialog for direct PDF preview where the PDF is already generated.
///
/// Shows the PDF with "Exportieren" and "Abbrechen" buttons.
class SimplePdfPreviewDialog extends ConsumerStatefulWidget {
  final Uint8List pdfData;
  final String title;

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

  Future<void> _savePdfToFile(BuildContext context) async {
    setState(() => _isSaving = true);

    try {
      String? initialDirectory;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        final setting = await repo.getSetting('pfad_export');
        if (setting?.wert != null && setting!.wert!.isNotEmpty) {
          initialDirectory = setting.wert;
        }
      } catch (_) {}

      final fileName = _generateFileName();

      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF-Datei speichern',
        fileName: fileName,
        initialDirectory: initialDirectory,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (filePath == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      final file = File(filePath);
      await file.writeAsBytes(widget.pdfData);

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
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
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
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 800,
          height: 700,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Schließen',
                    ),
                  ],
                ),
              ),

              // ── Preview ─────────────────────────────────────────────
              Expanded(
                child: PdfPreview(
                  build: (format) => widget.pdfData,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: _generateFileName(),
                  scrollViewDecoration: const BoxDecoration(),
                ),
              ),

              // ── Action bar ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _savePdfToFile(context),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_alt),
                      label: const Text('Exportieren'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateFileName() {
    final sanitized = widget.title
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final date = DateTime.now().toIso8601String().split('T').first;
    return '${sanitized}_$date.pdf';
  }
}
