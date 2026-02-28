import 'package:freezed_annotation/freezed_annotation.dart';

part 'waren_row_data.freezed.dart';

@freezed
abstract class WarenRowData with _$WarenRowData {
  const factory WarenRowData({
    required int id,
    required String bezeichnung,
    String? beschreibung,
    String? kategorie,
    String? groesse,
    String? farbe,
    String? geschlecht,
    String? material,
    double? einkaufspreis,
    required double bruttopreis,
    required double nettopreis, // Computed at runtime via Stammdaten
    required int bestand,
    required int mindestbestand,
    String? lieferant,
    String? hersteller,
    String? herstellerArtikelnr,
    double? gewichtKg,
    String? einheit,
    String? bildUrl,
    required bool aktiv,
    required DateTime erstelltAm,
    required DateTime aktualisiertAm,
    int? bemerkungId,
  }) = _WarenRowData;
}
