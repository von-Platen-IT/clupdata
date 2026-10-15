import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/datum_utils.dart';

part 'faelligkeit_service.g.dart';

/// Service für Fälligkeits- und Überfälligkeits-Berechnungen.
///
/// Zentrale Quelle für alle Zeit-Regeln der Billing-Domäne
/// (siehe [`plans/rechnungsstellung-redesign.md`](../../../../plans/rechnungsstellung-redesign.md)).
class FaelligkeitService {
  const FaelligkeitService({this.zahlungszielTage = 14, this.toleranzTage = 0});

  /// Standard-Zahlungsziel in Tagen (Stammdaten `zahlungsziel_tage`).
  final int zahlungszielTage;

  /// Schonfrist in Tagen, bis ein Beleg als überfällig gilt
  /// (Stammdaten `toleranz_tage_ueberfaellig`).
  final int toleranzTage;

  /// Berechnet die Fälligkeit: [erstellungsDatum] + [zahlungszielTage].
  DateTime berechneFaelligkeit(DateTime erstellungsDatum) {
    return addiereTage(erstellungsDatum, zahlungszielTage);
  }

  /// Berechnet die Fälligkeit mit individuellem [zielTage]-Wert.
  DateTime berechneFaelligkeitMitZiel(DateTime erstellungsDatum, int zielTage) {
    return addiereTage(erstellungsDatum, zielTage);
  }

  /// True, wenn [faelligAm] unter Berücksichtigung der Toleranz überschritten ist.
  ///
  /// Kalendertag-basiert: Am Fälligkeitstag selbst ist ein Beleg noch nicht
  /// überfällig, erst ab dem Folgetag (zzgl. [toleranzTage]).
  bool istUeberfaellig(DateTime faelligAm, {DateTime? heute}) {
    final jetzt = heute ?? DateTime.now();
    return differenzInTagen(faelligAm, jetzt) > toleranzTage;
  }

  /// Tage seit Fälligkeit (negativ = noch nicht fällig).
  int tageSeitFaelligkeit(DateTime faelligAm, {DateTime? heute}) {
    final jetzt = heute ?? DateTime.now();
    return differenzInTagen(faelligAm, jetzt);
  }
}

/// Provider für [`FaelligkeitService`] mit Stammdaten-Defaults.
@riverpod
FaelligkeitService faelligkeitService(Ref ref) {
  // TODO(architekt): Stammdaten-Schlüssel `zahlungsziel_tage` /
  // `toleranz_tage_ueberfaellig` auslesen, sobald Stammdaten-Repository
  // die Werte liefert. Bis dahin gelten die Defaults aus ADR-004.
  return const FaelligkeitService();
}
