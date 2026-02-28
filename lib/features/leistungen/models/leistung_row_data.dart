import 'package:freezed_annotation/freezed_annotation.dart';

part 'leistung_row_data.freezed.dart';

@freezed
abstract class LeistungRowData with _$LeistungRowData {
  const factory LeistungRowData({
    required int id,
    required String name,
    required String laufzeit,
    required int preisId,
    required double bruttopreis,
    required double nettopreis, // Computed at runtime via Stammdaten
    int? bemerkungId,
  }) = _LeistungRowData;
}
