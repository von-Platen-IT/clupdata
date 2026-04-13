import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/members/data/members_repository.dart';
import 'package:clupdata/features/leistungen/data/leistungen_repository.dart';
import 'package:clupdata/features/leistungen/data/preise_repository.dart';
import '../../domain/models/member_row_data.dart';

final _membersStreamProvider = StreamProvider<List<Mitglied>>((ref) {
  return ref.watch(membersRepositoryProvider).watchMembers();
});

final _leistungenStreamProvider = StreamProvider<List<LeistungItem>>((ref) {
  return ref.watch(leistungenRepositoryProvider).watchLeistungen();
});

final _preiseStreamProvider = StreamProvider<List<PreisItem>>((ref) {
  return ref.watch(preiseRepositoryProvider).watchPreise();
});

final bemerkungForMemberProvider = StreamProvider.family<BemerkungData?, int>((
  ref,
  memberId,
) {
  return ref.watch(membersRepositoryProvider).watchBemerkungForMember(memberId);
});

final membersGridRowsProvider = Provider<AsyncValue<List<MemberRowData>>>((
  ref,
) {
  final membersResult = ref.watch(_membersStreamProvider);
  final leistungenResult = ref.watch(_leistungenStreamProvider);
  final preiseResult = ref.watch(_preiseStreamProvider);

  if (membersResult.hasError) {
    return AsyncValue.error(
      membersResult.error!,
      membersResult.stackTrace ?? StackTrace.current,
    );
  }
  if (preiseResult.hasError) {
    return AsyncValue.error(
      preiseResult.error!,
      preiseResult.stackTrace ?? StackTrace.current,
    );
  }

  // If we don't have basic data yet, and it's loading
  if (!membersResult.hasValue ||
      !leistungenResult.hasValue ||
      !preiseResult.hasValue) {
    return const AsyncValue.loading();
  }

  final List<Mitglied> members = membersResult.value!;
  final List<LeistungItem> leistungen = leistungenResult.value!;
  final List<PreisItem> preise = preiseResult.value!;

  final leistungMap = {for (var l in leistungen) l.id: l};
  final preiseMap = {for (var p in preise) p.id: p};

  final rows = members.map((m) {
    final leistung = m.leistungId != null ? leistungMap[m.leistungId] : null;
    final preis = m.preisId != null ? preiseMap[m.preisId] : null;

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
      beitrag: preis?.bruttopreis,
    );
  }).toList();

  return AsyncValue.data(rows);
});
