import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/export_data_repository_provider.dart';
import 'batch_export_service.dart';

part 'batch_pdf_exporter_provider.g.dart';

/// Provider for batch PDF export operations.
///
/// Uses [BatchExportService] without summary generators for simple
/// batch exports. For exports with summary generation, use
/// [BatchExportService] directly with an [AppDatabase].
@riverpod
BatchExportService batchPdfExporter(Ref ref) {
  return BatchExportService(repository: ref.watch(exportDataRepositoryProvider));
}
