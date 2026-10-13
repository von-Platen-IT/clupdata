import 'package:freezed_annotation/freezed_annotation.dart';

part 'kursplan_termin_row_data.freezed.dart';

/// Join-Zeile eines Kurstermins mit den Kursdaten (Name, Farbe, Sportart).
///
/// Wird für das Wochen-Raster und die Legende verwendet.
@Freezed(toJson: false, fromJson: false)
abstract class KursplanTerminRowData with _$KursplanTerminRowData {
  const factory KursplanTerminRowData({
    /// Termin-ID (`kursplan_termin.id`).
    required int id,

    /// Zugehöriger Kursplan.
    required int kursplanId,

    /// Referenzierter Kurs.
    required int kursId,

    /// Anzeigename des Kurses.
    required String kursName,

    /// Kampfsportart des Kurses (z. B. „Boxen").
    required String kampfsportart,

    /// Hex-Farbe `#RRGGBB` des Kurses.
    required String farbe,

    /// 1 = Montag … 7 = Sonntag.
    required int wochentag,

    /// Startzeit im Format `HH:mm`.
    required String startzeit,

    /// Endzeit im Format `HH:mm`; NULL = offenes Ende.
    String? endezeit,
  }) = _KursplanTerminRowData;

  const KursplanTerminRowData._();

  /// Startzeit in Minuten seit Mitternacht.
  int get startMinuten => _parse(startzeit);

  /// Endzeit in Minuten seit Mitternacht.
  /// Ohne [endezeit] wird eine Standarddauer von 60 Minuten angenommen.
  int get endMinuten =>
      endezeit == null ? _parse(startzeit) + 60 : _parse(endezeit!);

  static int _parse(String zeit) {
    final teile = zeit.split(':');
    return int.parse(teile[0]) * 60 + int.parse(teile[1]);
  }
}
