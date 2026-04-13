import 'package:clupdata/core/database/database.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'waren_detail.freezed.dart';

/// Data class holding a Waren item with its associated Bemerkung.
@Freezed(toJson: false, fromJson: false)
abstract class WarenDetail with _$WarenDetail {
  const factory WarenDetail({
    required WarenItem ware,
    BemerkungData? bemerkung,
  }) = _WarenDetail;
}
