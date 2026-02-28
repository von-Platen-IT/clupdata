import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/members/data/members_repository.dart';
import 'package:clupdata/features/leistungen/data/leistungen_repository.dart';
import '../../models/member_row_data.dart';

final _membersStreamProvider = StreamProvider<List<Mitglied>>((ref) {
  return ref.watch(membersRepositoryProvider).watchMembers();
});

final _leistungenStreamProvider = StreamProvider<List<LeistungItem>>((ref) {
  return ref.watch(leistungenRepositoryProvider).watchLeistungen();
});

final bemerkungForMemberProvider = StreamProvider.family<BemerkungData?, int>((ref, memberId) {
  return ref.watch(membersRepositoryProvider).watchBemerkungForMember(memberId);
});

final membersGridRowsProvider = Provider<AsyncValue<List<MemberRowData>>>((ref) {
  final membersResult = ref.watch(_membersStreamProvider);
  final leistungenResult = ref.watch(_leistungenStreamProvider);

  if (membersResult.isLoading || leistungenResult.isLoading) {
    return const AsyncValue.loading();
  }

  if (membersResult.hasError) {
    return AsyncValue.error(membersResult.error!, membersResult.stackTrace ?? StackTrace.current);
  }

  final List<Mitglied> members = membersResult.hasValue ? membersResult.value! : [];
  final List<LeistungItem> leistungen = leistungenResult.hasValue ? leistungenResult.value! : [];

  final leistungMap = {
    for (var l in leistungen) l.id: l
  };

  final rows = members.map((m) {
    final leistung = m.leistungId != null ? leistungMap[m.leistungId] : null;

    int? alter;
    if (m.geboren != null) {
      final days = DateTime.now().difference(m.geboren!).inDays;
      alter = (days / 365.25).floor();
    }

    return MemberRowData(
      id: m.id,
      name: m.name,
      vorname: m.vorname,
      ort: m.ort,
      plz: m.plz,
      telefon1: m.telefon1,
      telefon2: m.telefon2,
      email: m.email,
      leistungName: leistung?.name,
      vertragLaufzeitVon: m.vertragLaufzeitVon,
      vertragLaufzeitBis: m.vertragLaufzeitBis,
      vertragKontierung: m.vertragKontierung,
      alter: alter,
    );
  }).toList();

  return AsyncValue.data(rows);
});
