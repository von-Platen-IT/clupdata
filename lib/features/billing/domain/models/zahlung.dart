import 'zahlungsart.dart';

/// Domain-Model eines Zahlungseingangs (auch Teilzahlung oder
/// Gutschrift-Ausgleich mit negativem [betrag]).
///
/// Jede Zahlung referenziert genau einen Beleg – entweder einen
/// Beitrag (1:1-Leistung) oder eine Waren-Rechnung (N-Positionen).
class Zahlung {
  const Zahlung({
    required this.id,
    required this.betrag,
    required this.datum,
    required this.zahlungsart,
    this.beitragId,
    this.rechnungId,
    this.bemerkung,
    this.uuid,
    this.createdAt,
  });

  final int id;
  final String? uuid;

  /// Bezug auf einen Beitrag (XOR mit [rechnungId]).
  final int? beitragId;

  /// Bezug auf eine Rechnung (XOR mit [beitragId]).
  final int? rechnungId;

  /// Positiv = Zahlungseingang, negativ = Gutschrift-Ausgleich.
  final double betrag;
  final DateTime datum;
  final Zahlungsart zahlungsart;
  final String? bemerkung;
  final DateTime? createdAt;

  /// True, wenn die Zahlung zu einem Beitrag gehört.
  bool get istBeitragsZahlung => beitragId != null;

  @override
  String toString() =>
      'Zahlung(id: $id, betrag: $betrag, art: ${zahlungsart.name})';
}
