import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/backup_config.dart';

part 'backup_config_repository.g.dart';

/// Zugriff auf die Backup-Konfiguration im `stammdaten`-Store.
///
/// Neue Schlüssel werden beim ersten Zugriff per `getOrCreate` angelegt –
/// kein Schema-Change (siehe ADR-003). `backup_letztes_datum` wird nur
/// programmintern von [setLetztesDatum] geschrieben.
class BackupConfigRepository {
  static const String schluesselPfad = 'pfad_backup';
  static const String schluesselIntervall = 'backup_intervall_tage';
  static const String schluesselAutoAktiv = 'backup_automatisch_aktiv';
  static const String schluesselLetztesDatum = 'backup_letztes_datum';

  /// Metadaten der Backup-Schlüssel (Typ + Bezeichnung für getOrCreate).
  static const Map<String, ({String typ, String bezeichnung})> metadaten = {
    schluesselPfad: (
      typ: 'string',
      bezeichnung: 'Backup-Verzeichnis (automatische Sicherungen)',
    ),
    schluesselIntervall: (
      typ: 'integer',
      bezeichnung: 'Backup-Intervall (Tage)',
    ),
    schluesselAutoAktiv: (
      typ: 'boolean',
      bezeichnung: 'Automatische Datensicherung beim Programmstart',
    ),
    schluesselLetztesDatum: (
      typ: 'date',
      bezeichnung: 'Zeitpunkt des letzten erfolgreichen Backups',
    ),
  };

  final AppDatabase db;

  BackupConfigRepository(this.db);

  /// Lädt die vollständige Backup-Konfiguration (mit Default-Werten).
  Future<BackupConfig> loadConfig() async {
    final pfad = await _getOrCreate(schluesselPfad, standardWert: '');
    final intervall = await _getOrCreate(
      schluesselIntervall,
      standardWert: '7',
    );
    final autoAktiv = await _getOrCreate(
      schluesselAutoAktiv,
      standardWert: '1',
    );
    final letztesDatum = await _getOrCreate(
      schluesselLetztesDatum,
      standardWert: '',
      aenderbar: false,
    );

    return BackupConfig(
      pfad: pfad.wert ?? '',
      intervallTage: int.tryParse(intervall.wert ?? '') ?? 7,
      autoAktiv: (autoAktiv.wert ?? '1') == '1',
      letztesDatum: DateTime.tryParse(letztesDatum.wert ?? ''),
    );
  }

  /// Setzt das Backup-Intervall in Tagen (mindestens 1).
  Future<void> setIntervall(int tage) async {
    await _updateWert(schluesselIntervall, '${tage < 1 ? 1 : tage}');
  }

  /// Aktiviert/deaktiviert das automatische Backup beim Start.
  Future<void> setAutoAktiv(bool aktiv) async {
    await _updateWert(schluesselAutoAktiv, aktiv ? '1' : '0');
  }

  /// Setzt das Zielverzeichnis für automatische Backups.
  Future<void> setPfad(String pfad) async {
    await _updateWert(schluesselPfad, pfad);
  }

  /// Speichert den Zeitpunkt des letzten erfolgreichen Backups (nur intern).
  Future<void> setLetztesDatum(DateTime zeitpunkt) async {
    await _updateWert(schluesselLetztesDatum, zeitpunkt.toIso8601String());
  }

  // ── Hilfsmethoden ──────────────────────────────────────────────────────

  Future<StammdatenItem> _getOrCreate(
    String schluessel, {
    required String standardWert,
    bool aenderbar = true,
  }) async {
    final vorhanden = await _get(schluessel);
    if (vorhanden != null) return vorhanden;

    final meta = metadaten[schluessel]!;
    await db
        .into(db.stammdaten)
        .insert(
          StammdatenCompanion.insert(
            schluessel: schluessel,
            wert: Value(standardWert),
            typ: meta.typ,
            kategorie: 'programm',
            bezeichnung: meta.bezeichnung,
            aenderbar: Value(aenderbar ? 1 : 0),
            systemPflicht: const Value(true),
          ),
        );
    return (await _get(schluessel))!;
  }

  Future<StammdatenItem?> _get(String schluessel) {
    return (db.select(
      db.stammdaten,
    )..where((s) => s.schluessel.equals(schluessel))).getSingleOrNull();
  }

  Future<void> _updateWert(String schluessel, String wert) async {
    final eintrag = await _getOrCreate(schluessel, standardWert: '');
    await (db.update(db.stammdaten)..where((s) => s.id.equals(eintrag.id)))
        .write(StammdatenCompanion(wert: Value(wert)));
  }
}

/// Riverpod provider for [BackupConfigRepository].
@riverpod
BackupConfigRepository backupConfigRepository(Ref ref) {
  return BackupConfigRepository(ref.watch(appDatabaseProvider));
}
