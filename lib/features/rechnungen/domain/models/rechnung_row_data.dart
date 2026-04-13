import 'package:clupdata/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rechnung_row_data.freezed.dart';

/// Data class holding a joined Rechnung with its related names for display.
@Freezed(toJson: false, fromJson: false)
abstract class RechnungRowData with _$RechnungRowData {
  const RechnungRowData._();

  const factory RechnungRowData({
    required Rechnung rechnung,
    required String kundeName,
  }) = _RechnungRowData;

  /// Manual JSON serialization for DataGrid export/CRUD.
  Map<String, dynamic> toJson() => {
    'id': rechnung.id,
    'rechnungsnummer': rechnung.rechnungsnummer,
    'kundeName': kundeName,
    'status': rechnung.status,
    'datum': rechnung.datum.toIso8601String(),
    'betragNetto': rechnung.betragNetto,
    'betragBrutto': rechnung.betragBrutto,
  };

  /// Manual JSON deserialization for DataGrid CRUD.
  static RechnungRowData fromJson(Map<String, dynamic> json) {
    throw UnsupportedError(
      'RechnungRowData.fromJson is not supported – '
      'use repository streams instead.',
    );
  }
}
