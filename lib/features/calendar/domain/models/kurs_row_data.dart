import 'package:freezed_annotation/freezed_annotation.dart';

part 'kurs_row_data.freezed.dart';

/// Anzeige-/Transfermodell eines Kurses (Kurstyp).
///
/// Wird von `@riverpod`-Providern geliefert (Drift-Roh-Typen sind in
/// generierten Provider-Signaturen nicht zulässig).
@Freezed(toJson: false, fromJson: false)
abstract class KursRowData with _$KursRowData {
  const factory KursRowData({
    required int id,
    required String name,
    required String kampfsportart,

    /// Hex-Farbe `#RRGGBB` für die Kursplan-Darstellung.
    required String farbe,
  }) = _KursRowData;
}
