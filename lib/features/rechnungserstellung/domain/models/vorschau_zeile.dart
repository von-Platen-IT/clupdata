import 'package:freezed_annotation/freezed_annotation.dart';

part 'vorschau_zeile.freezed.dart';

/// Eine Zeile der Abrechnungs-Vorschau (Wizard-Schritt 4).
///
/// Repräsentiert genau einen zu erstellenden `beitrag`-Datensatz inklusive
/// des Preis-Snapshots. Zeilen mit [inkludiert] = `false` werden bei der
/// Ausführung übersprungen, Zeilen mit [bereitsAbgerechnet] = `true` sind
/// per Standard abgewählt (Idempotenz sichtbar machen).
@Freezed(toJson: false, fromJson: false)
abstract class VorschauZeile with _$VorschauZeile {
  const factory VorschauZeile({
    /// Mitglied, das abgerechnet wird.
    required int mitgliedId,

    /// Anzeigename „Name, Vorname".
    required String mitgliedName,

    /// Leistung (Kurs/Vertragsart) des Beitrags.
    required int leistungId,

    /// Anzeigename der Leistung.
    required String leistungName,

    /// Abrechnungszeitraum (Periodenanfang, z. B. 1.6.2026).
    required DateTime abrechnungsZeitraum,

    /// Bruttobetrag des Preis-Snapshots (überschreibbar in der Vorschau).
    required double betrag,

    /// Ob der Beitrag bei der Ausführung erstellt wird.
    @Default(true) bool inkludiert,

    /// Ob für Mitglied + Periode bereits ein Beitrag existiert.
    @Default(false) bool bereitsAbgerechnet,

    /// Optionaler Hinweis (z. B. „abweichender Einzelpreis").
    String? hinweis,
  }) = _VorschauZeile;

  const VorschauZeile._();

  /// True, wenn die Zeile tatsächlich erstellt werden kann.
  bool get kannErstelltWerden => inkludiert && !bereitsAbgerechnet;
}
