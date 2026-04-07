import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/export_data_repository_provider.dart';
import 'batch_pdf_exporter.dart';

part 'batch_pdf_exporter_provider.g.dart';

/// Provider for the [BatchPdfExporter].
@riverpod
BatchPdfExporter batchPdfExporter(Ref ref) {
  return BatchPdfExporter(ref.watch(exportDataRepositoryProvider));
}
