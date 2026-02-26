import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/members/data/members_repository.dart';
import 'package:clupdata/features/leistungen/data/leistungen_repository.dart';

final _membersStreamProvider = StreamProvider<List<Mitglied>>((ref) {
  return ref.watch(membersRepositoryProvider).watchMembers();
});

final _leistungenStreamProvider = StreamProvider<List<LeistungItem>>((ref) {
  return ref.watch(leistungenRepositoryProvider).watchLeistungen();
});

final membersGridRowsProvider = Provider<AsyncValue<List<PlutoRow>>>((ref) {
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

  final dateFormat = DateFormat('dd.MM.yyyy');
  String formatDate(DateTime? date) => date != null ? dateFormat.format(date) : '';

  final rows = members.map((m) {
    final leistung = m.leistungId != null ? leistungMap[m.leistungId] : null;

    int? alter;
    if (m.geboren != null) {
      final days = DateTime.now().difference(m.geboren!).inDays;
      alter = (days / 365.25).floor();
    }

    return PlutoRow(cells: {
      'id': PlutoCell(value: m.id),
      'name': PlutoCell(value: m.name),
      'vorname': PlutoCell(value: m.vorname),
      'ort': PlutoCell(value: m.ort ?? ''),
      'telefon1': PlutoCell(value: m.telefon1 ?? ''),
      'email': PlutoCell(value: m.email ?? ''),
      'leistung_name': PlutoCell(value: leistung?.name ?? ''),
      'vertrag_laufzeit_von': PlutoCell(value: formatDate(m.vertragLaufzeitVon)),
      'vertrag_laufzeit_bis': PlutoCell(value: formatDate(m.vertragLaufzeitBis)),
      'alter': PlutoCell(value: alter ?? ''),
      'plz': PlutoCell(value: m.plz ?? ''),
      'telefon2': PlutoCell(value: m.telefon2 ?? ''),
      'vertrag_kontierung': PlutoCell(value: formatDate(m.vertragKontierung)),
    });
  }).toList();

  return AsyncValue.data(rows);
});
