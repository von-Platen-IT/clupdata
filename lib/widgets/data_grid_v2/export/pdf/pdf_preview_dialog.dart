import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Dialog showing PDF preview with print and save capabilities.
///
/// Uses the `printing` package to render a native PDF preview
/// with standard actions (print, share, save).
///
/// Example:
/// ```dart
/// await showDialog(
///   context: context,
///   builder: (_) => PdfPreviewDialog(
///     pdfData: pdfBytes,
///     title: 'Mitgliederliste',
///   ),
/// );
/// ```
class PdfPreviewDialog extends StatelessWidget {
  /// The PDF document as byte array.
  final Uint8List pdfData;

  /// The title shown in the dialog header.
  final String title;

  /// Creates a [PdfPreviewDialog] with the given [pdfData] and [title].
  const PdfPreviewDialog({
    super.key,
    required this.pdfData,
    required this.title,
  });

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
                  build: (format) => pdfData,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.picture_as_pdf,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
    final sanitized = title
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final date = DateTime.now().toIso8601String().split('T').first;
    return '${sanitized}_$date.pdf';
  }
}
