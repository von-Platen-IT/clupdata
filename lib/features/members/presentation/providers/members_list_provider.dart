import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/members/data/members_repository.dart';
import '../../domain/models/member_row_data.dart';
import '../../domain/models/leistung_dropdown_item.dart';

final bemerkungForMemberProvider = StreamProvider.family<BemerkungData?, int>((
  ref,
  memberId,
) {
  return ref.watch(membersRepositoryProvider).watchBemerkungForMember(memberId);
});

/// Streams the full list of [MemberRowData] via SQL-JOIN (Issue 3.1).
/// Previously this used 3 separate streams with an in-memory join in Dart,
/// which caused unnecessary rebuilds when Leistung or Preis changed.
final membersGridRowsProvider = StreamProvider<List<MemberRowData>>((ref) {
  return ref.watch(membersRepositoryProvider).watchMembersWithDetails();
});

/// Streams available Leistungen for the member edit dialog dropdown.
/// Decoupled from the Leistungen feature module (Issue 4.2).
final leistungenForDropdownProvider =
    StreamProvider<List<LeistungDropdownItem>>((ref) {
      return ref.watch(membersRepositoryProvider).watchLeistungenForDropdown();
    });
