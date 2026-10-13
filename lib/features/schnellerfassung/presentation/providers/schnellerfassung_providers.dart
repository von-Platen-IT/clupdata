import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/vorlage_repository.dart';
import '../../domain/models/sitzungs_protokoll_state.dart';
import '../../domain/models/vorlage.dart';

part 'schnellerfassung_providers.g.dart';

/// Alle gespeicherten Eingabe-Vorlagen.
@riverpod
Future<List<Vorlage>> vorlagenListe(Ref ref) async {
  final repo = ref.watch(vorlageRepositoryProvider);
  return repo.loadVorlagen();
}

/// Protokoll der laufenden Sitzung (erfasste Namen + Duplikat-Warnung).
@riverpod
class SitzungsProtokoll extends _$SitzungsProtokoll {
  @override
  SitzungsProtokollState build() => const SitzungsProtokollState();

  /// Erfassten Datensatz im Protokoll vermerken.
  void fuegeHinzu(String anzeigeName) {
    state = state.copyWith(namen: [...state.namen, anzeigeName]);
  }

  /// Duplikat-Warnung setzen oder entfernen.
  void setzeWarnung(String? warnung) {
    state = state.copyWith(duplikatWarnung: warnung);
  }

  /// Protokoll leeren („Liste leeren").
  void leere() => state = const SitzungsProtokollState();
}
