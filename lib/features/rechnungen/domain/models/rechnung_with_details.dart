import 'package:clupdata/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rechnung_with_details.freezed.dart';

/// Data class holding complete Rechnung details including positions and bemerkung.
@Freezed(toJson: false, fromJson: false)
abstract class RechnungWithDetails with _$RechnungWithDetails {
  const factory RechnungWithDetails({
    required Rechnung rechnung,
    required List<RechnungPosition> positionen,
    required String kundeName,
    BemerkungData? bemerkung,
  }) = _RechnungWithDetails;
}
