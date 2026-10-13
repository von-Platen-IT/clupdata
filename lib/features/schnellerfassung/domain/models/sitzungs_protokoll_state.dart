import 'package:freezed_annotation/freezed_annotation.dart';

part 'sitzungs_protokoll_state.freezed.dart';

/// Protokoll der laufenden Schnellerfassungs-Sitzung.
///
/// Zeigt die bereits erfassten Datensätze als Kontrolle und enthält
/// die (nicht blockierende) Duplikat-Warnung.
@Freezed(toJson: false, fromJson: false)
abstract class SitzungsProtokollState with _$SitzungsProtokollState {
  const factory SitzungsProtokollState({
    /// Anzeigenamen der erfassten Datensätze („Name, Vorname").
    @Default([]) List<String> namen,

    /// Aktuelle Duplikat-Warnung; `null` = keine Warnung.
    String? duplikatWarnung,
  }) = _SitzungsProtokollState;

  const SitzungsProtokollState._();

  /// Anzahl der in dieser Sitzung erfassten Datensätze.
  int get anzahl => namen.length;
}
