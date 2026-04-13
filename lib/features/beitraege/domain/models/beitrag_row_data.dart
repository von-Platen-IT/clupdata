import 'package:clupdata/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'beitrag_row_data.freezed.dart';

/// Data class holding a joined Beitrag with its related names for display.
@Freezed(toJson: false, fromJson: false)
abstract class BeitragRowData with _$BeitragRowData {
  const BeitragRowData._();

  const factory BeitragRowData({
    required Beitrag beitrag,
    required String mitgliedName,
    required String leistungName,
  }) = _BeitragRowData;

  /// Manual JSON serialization for DataGrid export/CRUD.
  Map<String, dynamic> toJson() => {
    'id': beitrag.id,
    'rechnungsnummer': beitrag.rechnungsnummer,
    'mitgliedName': mitgliedName,
    'leistungName': leistungName,
    'status': beitrag.status,
    'kontiertAm': beitrag.kontiertAm.toIso8601String(),
  };

  /// Manual JSON deserialization for DataGrid CRUD.
  static BeitragRowData fromJson(Map<String, dynamic> json) {
    throw UnsupportedError(
      'BeitragRowData.fromJson is not supported – '
      'use repository streams instead.',
    );
  }
}
