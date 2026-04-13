import 'package:clupdata/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rechnung_with_positionen.freezed.dart';

/// Data class holding a complete Rechnung with all its positions.
@Freezed(toJson: false, fromJson: false)
abstract class RechnungWithPositionen with _$RechnungWithPositionen {
  const factory RechnungWithPositionen({
    required Rechnung rechnung,
    required List<RechnungPosition> positionen,
    required String kundeName,
  }) = _RechnungWithPositionen;
}
