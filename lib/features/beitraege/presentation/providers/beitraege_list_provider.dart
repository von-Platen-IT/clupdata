import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:clupdata/features/beitraege/data/beitraege_repository.dart';
import 'package:clupdata/features/beitraege/domain/models/beitrag_row_data.dart';

part 'beitraege_list_provider.g.dart';

/// Stream provider exposing the joined Beiträge list.
@riverpod
Stream<List<BeitragRowData>> beitraegeList(Ref ref) {
  return ref.watch(beitraegeRepositoryProvider).watchBeitraege();
}

/// Stream provider for a single Beitrag by ID.
/// More efficient than watching the entire list when only one item is needed.
@riverpod
Stream<BeitragRowData?> singleBeitrag(Ref ref, int beitragId) {
  return ref.watch(beitraegeRepositoryProvider).watchSingleBeitrag(beitragId);
}
