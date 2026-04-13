import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:clupdata/features/rechnungen/data/rechnungen_repository.dart';
import 'package:clupdata/features/rechnungen/domain/models/rechnung_row_data.dart';
import 'package:clupdata/features/rechnungen/domain/models/rechnung_with_details.dart';

part 'rechnungen_list_provider.g.dart';

/// Stream provider exposing the joined Rechnungen list.
@riverpod
Stream<List<RechnungRowData>> rechnungenList(Ref ref) {
  return ref.watch(rechnungenRepositoryProvider).watchRechnungen();
}

/// Future provider for a single Rechnung with all details.
/// Uses a family to enable caching per rechnungId.
@riverpod
Future<RechnungWithDetails?> rechnungWithDetails(Ref ref, int rechnungId) {
  return ref
      .watch(rechnungenRepositoryProvider)
      .getRechnungWithDetails(rechnungId);
}
