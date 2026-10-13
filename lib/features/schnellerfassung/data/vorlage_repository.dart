import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/models/schnellerfassung_felder.dart';
import '../domain/models/vorlage.dart';

part 'vorlage_repository.g.dart';

/// Speichert und verwaltet Eingabe-Vorlagen der Schnellerfassung.
///
/// Die Vorlagen liegen als JSON in `stammdaten`
/// (Schlüssel `vorlage_mitglied_<slug>`) – analog zum Backup-Konzept
/// (ADR-003): kein Schema-Change, `getOrCreate`-Muster.
class VorlageRepository {
  /// Präfix aller Mitglieder-Vorlagen.
  static const String praefix = 'vorlage_mitglied_';

  final AppDatabase db;

  VorlageRepository(this.db);

  /// Liefert alle gespeicherten Vorlagen, sortiert nach Name.
  Future<List<Vorlage>> loadVorlagen() async {
    final query = db.select(db.stammdaten)
      ..where((s) => s.schluessel.like('$praefix%'));

    final eintraege = await query.get();
    final vorlagen = <Vorlage>[];
    for (final e in eintraege) {
      final wert = e.wert;
      if (wert == null || wert.isEmpty) continue;
      try {
        final felder = jsonDecode(wert) as Map<String, dynamic>;
        vorlagen.add(
          Vorlage(
            name: e.bezeichnung,
            schluessel: e.schluessel,
            felder: felder.map((k, v) => MapEntry(k, v.toString())),
          ),
        );
      } catch (_) {
        // Defekte JSON-Einträge werden übersprungen.
      }
    }
    vorlagen.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return vorlagen;
  }

  /// Speichert eine Vorlage unter [name] mit den aktuellen [feldern].
  ///
  /// Eine bestehende Vorlage gleichen Namens wird überschrieben.
  Future<void> saveVorlage(String name, SchnellerfassungFelder felder) async {
    final slug = _slug(name);
    final schluessel = '$praefix$slug';
    final wert = jsonEncode(felder.toMap());

    final vorhanden = await _get(schluessel);
    if (vorhanden == null) {
      await db
          .into(db.stammdaten)
          .insert(
            StammdatenCompanion.insert(
              schluessel: schluessel,
              wert: Value(wert),
              typ: 'string',
              kategorie: 'programm',
              bezeichnung: name.trim(),
            ),
          );
    } else {
      await (db.update(
        db.stammdaten,
      )..where((s) => s.id.equals(vorhanden.id))).write(
        StammdatenCompanion(wert: Value(wert), bezeichnung: Value(name.trim())),
      );
    }
  }

  /// Löscht eine Vorlage anhand ihres Schlüssels.
  Future<void> deleteVorlage(String schluessel) async {
    await (db.delete(
      db.stammdaten,
    )..where((s) => s.schluessel.equals(schluessel))).go();
  }

  // ── Hilfsmethoden ──────────────────────────────────────────────────────

  Future<StammdatenItem?> _get(String schluessel) {
    return (db.select(
      db.stammdaten,
    )..where((s) => s.schluessel.equals(schluessel))).getSingleOrNull();
  }

  /// Erzeugt einen URL-sicheren Slug aus dem Vorlagennamen.
  String _slug(String name) {
    final bereinigt = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return bereinigt.isEmpty ? 'vorlage' : bereinigt;
  }
}

/// Riverpod provider for [VorlageRepository].
@riverpod
VorlageRepository vorlageRepository(Ref ref) {
  return VorlageRepository(ref.watch(appDatabaseProvider));
}
