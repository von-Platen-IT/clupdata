import 'package:freezed_annotation/freezed_annotation.dart';

part 'vorlage.freezed.dart';

/// Eine benannte Eingabe-Vorlage für die Schnellerfassung.
///
/// Die Feldwerte werden als JSON in `stammdaten` gespeichert
/// (Schlüssel `vorlage_mitglied_<slug>`, siehe `plans/schnellerfassung.md`).
@Freezed(toJson: false, fromJson: false)
abstract class Vorlage with _$Vorlage {
  const factory Vorlage({
    /// Anzeigename der Vorlage, z. B. „Erwachsene Boxen".
    required String name,

    /// Stammdaten-Schlüssel, unter dem die Vorlage gespeichert ist.
    required String schluessel,

    /// Feldwerte als Schlüssel/Wert-Paare (serialisierbar).
    required Map<String, String> felder,
  }) = _Vorlage;
}
