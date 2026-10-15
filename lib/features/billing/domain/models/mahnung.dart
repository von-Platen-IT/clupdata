/// Domain-Model einer dokumentierten Mahnstufe je Forderung.
///
/// Stufen-Definition: 1 = Zahlungserinnerung, 2 = 1. Mahnung,
/// 3 = 2. Mahnung, 4 = Inkasso/Eskalation.
class Mahnung {
  const Mahnung({
    required this.id,
    required this.stufe,
    required this.datum,
    required this.forderung,
    this.gebuehr = 0,
    this.beitragId,
    this.rechnungId,
    this.bemerkung,
    this.uuid,
  });

  final int id;
  final String? uuid;

  /// Bezug auf einen Beitrag (XOR mit [rechnungId]).
  final int? beitragId;

  /// Bezug auf eine Rechnung (XOR mit [beitragId]).
  final int? rechnungId;

  /// 1 = Zahlungserinnerung, 2 = 1. Mahnung, 3 = 2. Mahnung, 4 = Inkasso.
  final int stufe;
  final DateTime datum;
  final double gebuehr;
  final double forderung;
  final String? bemerkung;

  /// Anzeigename der Mahnstufe.
  String get stufeLabel => switch (stufe) {
    1 => 'Zahlungserinnerung',
    2 => '1. Mahnung',
    3 => '2. Mahnung',
    4 => 'Inkasso',
    _ => 'Stufe $stufe',
  };
}
