import 'package:freezed_annotation/freezed_annotation.dart';

part 'schnellerfassung_felder.freezed.dart';

/// Formularfelder der Mitglieder-Schnellerfassung.
///
/// Enthält die Kopierlogik für die Vorlagen-Mechanismen:
/// [alsNaechsteVorlage] (Auto-Vorlage) und Serialisierung für
/// benannte Vorlagen ([toMap]/[fromMap]).
@Freezed(toJson: false, fromJson: false)
abstract class SchnellerfassungFelder with _$SchnellerfassungFelder {
  const factory SchnellerfassungFelder({
    @Default('') String anrede,
    @Default('') String geschlecht,
    @Default('') String name,
    @Default('') String vorname,
    DateTime? geboren,
    @Default('') String plz,
    @Default('') String ort,
    @Default('') String strasse,
    @Default('') String hausnummer,
    @Default('') String telefon,
    @Default('') String email,
    int? leistungId,
    DateTime? vertragVon,
    @Default('') String bemerkung,
  }) = _SchnellerfassungFelder;

  const SchnellerfassungFelder._();

  /// Komplett leeres Formular.
  static const SchnellerfassungFelder leer = SchnellerfassungFelder();

  /// Auto-Vorlage für die nächste Eingabe: Komfortfelder bleiben gefüllt,
  /// Personenfelder werden geleert.
  SchnellerfassungFelder alsNaechsteVorlage() => copyWith(
    name: '',
    vorname: '',
    geboren: null,
    telefon: '',
    email: '',
    bemerkung: '',
  );

  /// Serialisiert die Felder für die Vorlagen-Speicherung in `stammdaten`.
  Map<String, String> toMap() => {
    'anrede': anrede,
    'geschlecht': geschlecht,
    'name': name,
    'vorname': vorname,
    'geboren': geboren?.toIso8601String() ?? '',
    'plz': plz,
    'ort': ort,
    'strasse': strasse,
    'hausnummer': hausnummer,
    'telefon': telefon,
    'email': email,
    'leistungId': leistungId?.toString() ?? '',
    'vertragVon': vertragVon?.toIso8601String() ?? '',
    'bemerkung': bemerkung,
  };

  /// Stellt die Felder aus einer gespeicherten Vorlage wieder her.
  static SchnellerfassungFelder fromMap(Map<String, dynamic> map) {
    return SchnellerfassungFelder(
      anrede: map['anrede'] as String? ?? '',
      geschlecht: map['geschlecht'] as String? ?? '',
      name: map['name'] as String? ?? '',
      vorname: map['vorname'] as String? ?? '',
      geboren: DateTime.tryParse(map['geboren'] as String? ?? ''),
      plz: map['plz'] as String? ?? '',
      ort: map['ort'] as String? ?? '',
      strasse: map['strasse'] as String? ?? '',
      hausnummer: map['hausnummer'] as String? ?? '',
      telefon: map['telefon'] as String? ?? '',
      email: map['email'] as String? ?? '',
      leistungId: int.tryParse(map['leistungId'] as String? ?? ''),
      vertragVon: DateTime.tryParse(map['vertragVon'] as String? ?? ''),
      bemerkung: map['bemerkung'] as String? ?? '',
    );
  }
}
