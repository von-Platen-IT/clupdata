import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/datum_utils.dart';

part 'backup_config.freezed.dart';

/// Backup-Konfiguration (gespeichert in `stammdaten`, siehe ADR-003).
@Freezed(toJson: false, fromJson: false)
abstract class BackupConfig with _$BackupConfig {
  const factory BackupConfig({
    /// Zielverzeichnis der automatischen Backups (`pfad_backup`).
    required String pfad,

    /// Intervall in Tagen zwischen zwei Sicherungen (`backup_intervall_tage`).
    required int intervallTage,

    /// Ob beim Programmstart automatisch gesichert wird
    /// (`backup_automatisch_aktiv`).
    required bool autoAktiv,

    /// Zeitpunkt des letzten erfolgreichen Backups (`backup_letztes_datum`),
    /// `null` = noch nie gesichert.
    DateTime? letztesDatum,
  }) = _BackupConfig;

  const BackupConfig._();

  /// Berechnet das Datum, ab dem die nächste Sicherung fällig ist.
  ///
  /// `null`, wenn noch nie gesichert wurde.
  DateTime? get naechstesFaellig {
    if (letztesDatum == null) return null;
    return addiereTage(letztesDatum!, intervallTage);
  }

  /// Prüft, ob zum Zeitpunkt [jetzt] ein Auto-Backup fällig wäre.
  bool istFaellig(DateTime jetzt) {
    if (!autoAktiv) return false;
    if (letztesDatum == null) return true;
    return differenzInTagen(letztesDatum!, jetzt) >= intervallTage;
  }
}
