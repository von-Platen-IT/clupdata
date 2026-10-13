import 'package:freezed_annotation/freezed_annotation.dart';

part 'kursplan_row_data.freezed.dart';

/// Anzeige-/Transfermodell eines Kursplans.
///
/// Wird von `@riverpod`-Providern geliefert (Drift-Roh-Typen sind in
/// generierten Provider-Signaturen nicht zulässig).
@Freezed(toJson: false, fromJson: false)
abstract class KursplanRowData with _$KursplanRowData {
  const factory KursplanRowData({
    required int id,
    required String name,

    /// Erste gültige Woche (Montag).
    required DateTime gueltigVon,

    /// Letzte gültige Woche (Montag); `null` = unbegrenzt.
    DateTime? gueltigBis,
  }) = _KursplanRowData;
}
