import 'package:freezed_annotation/freezed_annotation.dart';

part 'auto_backup_status_state.freezed.dart';

/// Status des Hintergrund-Backup-Tasks (dezente Anzeige im UI).
@Freezed(toJson: false, fromJson: false)
abstract class AutoBackupStatusState with _$AutoBackupStatusState {
  /// Kein Backup aktiv.
  const factory AutoBackupStatusState.idle() = _Idle;

  /// Ein Backup läuft gerade.
  const factory AutoBackupStatusState.running() = _Running;

  /// Letztes Backup erfolgreich abgeschlossen.
  const factory AutoBackupStatusState.success(DateTime zeitpunkt) = _Success;

  /// Letztes Backup fehlgeschlagen.
  const factory AutoBackupStatusState.error(String meldung) = _Error;
}
