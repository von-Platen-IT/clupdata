import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_eintrag.freezed.dart';

/// Eine im Backup-Verzeichnis gefundene Sicherungsdatei.
///
/// Wird aus dem Dateisystem gescannt (kein DB-Protokoll, siehe ADR-003).
@Freezed(toJson: false, fromJson: false)
abstract class BackupEintrag with _$BackupEintrag {
  const factory BackupEintrag({
    /// Dateiname, z. B. `clup_data_backup_2026-10-12_08-30.sqlite`.
    required String dateiname,

    /// Vollständiger Pfad der Datei.
    required String pfad,

    /// Dateigröße in Bytes.
    required int groesseBytes,

    /// Letztes Änderungsdatum der Datei.
    required DateTime erstelltAm,
  }) = _BackupEintrag;

  const BackupEintrag._();

  /// Deutsche Anzeige der Dateigröße (z. B. „2,1 MB").
  String get groesseAnzeige {
    if (groesseBytes < 1024) return '$groesseBytes B';
    if (groesseBytes < 1024 * 1024) {
      return '${(groesseBytes / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';
    }
    return '${(groesseBytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
}
