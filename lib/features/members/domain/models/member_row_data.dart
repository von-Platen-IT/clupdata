import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_row_data.freezed.dart';
part 'member_row_data.g.dart';

/// Encapsulates the Member data intended for display in the table,
/// including pre-calculated or joined properties like age or leistung.
@freezed
abstract class MemberRowData with _$MemberRowData {
  const MemberRowData._();

  const factory MemberRowData({
    required int id,
    required String name,
    required String vorname,
    String? ort,
    String? plz,
    String? telefon1,
    String? telefon2,
    String? email,
    String? leistungName,
    DateTime? vertragLaufzeitVon,
    DateTime? vertragLaufzeitBis,
    DateTime? vertragKontierung,
    DateTime? geboren,
    double? beitrag,
  }) = _MemberRowData;

  factory MemberRowData.fromJson(Map<String, dynamic> json) =>
      _$MemberRowDataFromJson(json);

  /// Berechnet das Alter aus dem Geburtsdatum.
  /// Wird nur bei Bedarf berechnet, nicht bei jedem Stream-Emit.
  int? get alter {
    if (geboren == null) return null;
    final days = DateTime.now().difference(geboren!).inDays;
    return (days / 365.25).floor();
  }
}
