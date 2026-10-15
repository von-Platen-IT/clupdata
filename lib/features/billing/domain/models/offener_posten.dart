import '../../../../core/utils/datum_utils.dart';

/// Offener Posten = Beitrag oder Waren-Rechnung mit offenem Saldo.
///
/// Vereinheitlicht beide Belegarten für die Offene-Posten-Liste und
/// das Mahnwesen. Der [saldo] ist die noch nicht bezahlte Restforderung.
class OffenerPosten {
  const OffenerPosten({
    required this.belegArt,
    required this.belegId,
    required this.bezeichnung,
    required this.nummer,
    required this.betrag,
    required this.saldo,
    required this.faelligAm,
    required this.status,
    this.kundeName,
  });

  final OffenerPostenArt belegArt;
  final int belegId;
  final String nummer;
  final String bezeichnung;
  final String? kundeName;
  final double betrag;
  final double saldo;
  final DateTime faelligAm;
  final String status;

  /// Tage seit Fälligkeit (positiv = überfällig), DST-sicher in Kalendertagen.
  int get tageUeberfaellig => differenzInTagen(faelligAm, DateTime.now());

  /// True, wenn die Fälligkeit überschritten ist.
  bool get istUeberfaellig => tageUeberfaellig > 0;
}

/// Art des Belegs hinter einem offenen Posten.
enum OffenerPostenArt {
  beitrag('Beitrag'),
  rechnung('Rechnung');

  const OffenerPostenArt(this.label);

  final String label;
}
