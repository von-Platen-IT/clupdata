import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/bemerkung_repository.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../members/data/members_repository.dart';
import '../domain/models/schnellerfassung_felder.dart';

part 'schnellerfassung_service.g.dart';

/// Service der Schnellerfassung: Speichern und Duplikat-Prüfung.
///
/// Nutzt den bewährten Pfad [`MembersRepository.addMember()`] – derselbe wie
/// der Einzel-Dialog. Die Duplikat-Prüfung ist **informativ** und blockiert
/// das Speichern nicht (bei Massenerfassungen sind Namensgleichheiten möglich).
class SchnellerfassungService {
  final AppDatabase db;
  final MembersRepository membersRepo;
  final BemerkungRepository bemerkungRepo;

  SchnellerfassungService(this.db, this.membersRepo, this.bemerkungRepo);

  /// Legt ein Mitglied aus den Formularfeldern an und liefert die neue ID.
  ///
  /// Die Vertragslaufzeit-Bis wird aus `leistung.laufzeit` berechnet
  /// (analog zum Mitglied-Bearbeiten-Dialog).
  Future<int> speichereMitglied(SchnellerfassungFelder felder) async {
    final laufzeitBis = await _berechneLaufzeitBis(
      felder.leistungId,
      felder.vertragVon,
    );
    final bemerkungText = felder.bemerkung.trim();
    final bemerkungId = bemerkungText.isEmpty
        ? null
        : await bemerkungRepo.saveBemerkungIfContent(
            null,
            'Bemerkung',
            bemerkungText,
          );
    return membersRepo.addMember(
      _toCompanion(felder, laufzeitBis, bemerkungId),
    );
  }

  /// Prüft auf ein mögliches Duplikat (gleicher Name + Vorname).
  ///
  /// Sucht in der Datenbank und in den Namen der laufenden Sitzung.
  Future<bool> istMoeglichesDuplikat({
    required String name,
    required String vorname,
    required List<String> sitzungsnamen,
  }) async {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return false;
    final v = vorname.trim().toLowerCase();
    final voll = '$n, $v';

    if (sitzungsnamen.any((s) => s.toLowerCase() == voll)) return true;

    final query = db.select(db.mitglieds)
      ..where((m) => m.name.lower().equals(n) & m.vorname.lower().equals(v));
    return (await query.get()).isNotEmpty;
  }

  /// Berechnet `vertrag_laufzeit_bis` aus der Leistungslaufzeit.
  ///
  /// - `monatlich` → +1 Monat, `quartalsweise` → +3 Monate,
  ///   `jaehrlich` → +1 Jahr, `einmalig` → gleiches Datum.
  Future<DateTime?> _berechneLaufzeitBis(int? leistungId, DateTime? von) async {
    if (von == null || leistungId == null) return null;
    final leistung = await (db.select(
      db.leistung,
    )..where((l) => l.id.equals(leistungId))).getSingleOrNull();
    if (leistung == null) return null;

    return switch (leistung.laufzeit) {
      'monatlich' => DateTime(von.year, von.month + 1, von.day),
      'quartalsweise' => DateTime(von.year, von.month + 3, von.day),
      'jaehrlich' => DateTime(von.year + 1, von.month, von.day),
      _ => von,
    };
  }

  MitgliedsCompanion _toCompanion(
    SchnellerfassungFelder f,
    DateTime? laufzeitBis,
    int? bemerkungId,
  ) {
    String? text(String wert) => wert.trim().isEmpty ? null : wert.trim();

    return MitgliedsCompanion.insert(
      name: f.name.trim(),
      vorname: f.vorname.trim(),
      anrede: Value(text(f.anrede)),
      geschlecht: Value(text(f.geschlecht)),
      geboren: Value(f.geboren),
      plz: Value(text(f.plz)),
      ort: Value(text(f.ort)),
      strasse: Value(text(f.strasse)),
      hausnummer: Value(text(f.hausnummer)),
      telefon1: Value(text(f.telefon)),
      email: Value(text(f.email)),
      leistungId: Value(f.leistungId),
      vertragKontierung: Value(f.vertragVon),
      vertragLaufzeitVon: Value(f.vertragVon),
      vertragLaufzeitBis: Value(laufzeitBis),
      bemerkungId: Value(bemerkungId),
    );
  }
}

/// Riverpod provider for [SchnellerfassungService].
@riverpod
SchnellerfassungService schnellerfassungService(Ref ref) {
  return SchnellerfassungService(
    ref.watch(appDatabaseProvider),
    ref.watch(membersRepositoryProvider),
    ref.watch(bemerkungRepositoryProvider),
  );
}
