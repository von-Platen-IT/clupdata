import 'package:clupdata/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leistungs_detail.freezed.dart';

/// Data class holding a Leistung with its associated Preis and Bemerkung.
@Freezed(toJson: false, fromJson: false)
abstract class LeistungsDetail with _$LeistungsDetail {
  const factory LeistungsDetail({
    required LeistungItem leistung,
    required PreisItem preis,
    BemerkungData? bemerkung,
  }) = _LeistungsDetail;
}
