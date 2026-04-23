import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/data/bemerkung_repository.dart';
import 'package:clupdata/core/providers/database_provider.dart';
import 'package:clupdata/features/rechnungen/domain/models/rechnung_row_data.dart';
import 'package:clupdata/features/rechnungen/domain/models/rechnung_with_positionen.dart';
import 'package:clupdata/features/rechnungen/domain/models/rechnung_with_details.dart';

part 'rechnungen_repository.g.dart';

/// Repository for all database operations on the [Rechnungen] table.
class RechnungenRepository {
  final AppDatabase _db;
  final BemerkungRepository _bemerkungRepo;
  RechnungenRepository(this._db, this._bemerkungRepo);

  // ── Bemerkung ─────────────────────────────────────────────────────────────

  /// Streams the [BemerkungData] linked to a [Rechnung] by [rechnungId].
  Stream<BemerkungData?> watchBemerkungForRechnung(int rechnungId) {
    final query = _db.select(_db.rechnungen).join([
      leftOuterJoin(
        _db.bemerkung,
        _db.bemerkung.id.equalsExp(_db.rechnungen.bemerkungId),
      ),
    ])..where(_db.rechnungen.id.equals(rechnungId));
    return query.watchSingleOrNull().map(
      (row) => row?.readTableOrNull(_db.bemerkung),
    );
  }

  // ── Rechnungen list ───────────────────────────────────────────────────────

  /// Streams the full list of [RechnungRowData], joined with Mitglied for name.
  Stream<List<RechnungRowData>> watchRechnungen() {
    final query = _db.select(_db.rechnungen).join([
      leftOuterJoin(
        _db.mitglieds,
        _db.mitglieds.id.equalsExp(_db.rechnungen.mitgliedId),
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final rechnung = row.readTable(_db.rechnungen);
        final mitglied = row.readTableOrNull(_db.mitglieds);

        // Determine customer name
        String kundeName;
        if (mitglied != null) {
          kundeName = '${mitglied.name}, ${mitglied.vorname}';
        } else {
          kundeName = rechnung.kundeName ?? 'Unbekannt';
        }

        return RechnungRowData(rechnung: rechnung, kundeName: kundeName);
      }).toList();
    });
  }

  /// Fetches a single [Rechnung] with all its [RechnungPositionen] by [id].
  Future<RechnungWithPositionen?> getRechnungById(int id) async {
    // Get the rechnung
    final rechnungQuery = _db.select(_db.rechnungen).join([
      leftOuterJoin(
        _db.mitglieds,
        _db.mitglieds.id.equalsExp(_db.rechnungen.mitgliedId),
      ),
    ])..where(_db.rechnungen.id.equals(id));

    final rechnungRow = await rechnungQuery.getSingleOrNull();
    if (rechnungRow == null) return null;

    final rechnung = rechnungRow.readTable(_db.rechnungen);
    final mitglied = rechnungRow.readTableOrNull(_db.mitglieds);

    // Determine customer name
    String kundeName;
    if (mitglied != null) {
      kundeName = '${mitglied.name}, ${mitglied.vorname}';
    } else {
      kundeName = rechnung.kundeName ?? 'Unbekannt';
    }

    // Get all positions
    final positionsQuery = _db.select(_db.rechnungPositionen)
      ..where((p) => p.rechnungId.equals(id))
      ..orderBy([(p) => OrderingTerm.asc(p.positionNr)]);

    final positionen = await positionsQuery.get();

    return RechnungWithPositionen(
      rechnung: rechnung,
      positionen: positionen,
      kundeName: kundeName,
    );
  }

  /// Fetches a single [Rechnung] with all details including positions and bemerkung.
  Future<RechnungWithDetails?> getRechnungWithDetails(int id) async {
    // Get the rechnung with Mitglied and Bemerkung
    final rechnungQuery = _db.select(_db.rechnungen).join([
      leftOuterJoin(
        _db.mitglieds,
        _db.mitglieds.id.equalsExp(_db.rechnungen.mitgliedId),
      ),
      leftOuterJoin(
        _db.bemerkung,
        _db.bemerkung.id.equalsExp(_db.rechnungen.bemerkungId),
      ),
    ])..where(_db.rechnungen.id.equals(id));

    final rechnungRow = await rechnungQuery.getSingleOrNull();
    if (rechnungRow == null) return null;

    final rechnung = rechnungRow.readTable(_db.rechnungen);
    final mitglied = rechnungRow.readTableOrNull(_db.mitglieds);
    final bemerkung = rechnungRow.readTableOrNull(_db.bemerkung);

    // Determine customer name
    String kundeName;
    if (mitglied != null) {
      kundeName = '${mitglied.name}, ${mitglied.vorname}';
    } else {
      kundeName = rechnung.kundeName ?? 'Unbekannt';
    }

    // Get all positions
    final positionsQuery = _db.select(_db.rechnungPositionen)
      ..where((p) => p.rechnungId.equals(id))
      ..orderBy([(p) => OrderingTerm.asc(p.positionNr)]);

    final positionen = await positionsQuery.get();

    return RechnungWithDetails(
      rechnung: rechnung,
      positionen: positionen,
      kundeName: kundeName,
      bemerkung: bemerkung,
    );
  }

  /// Updates a [Rechnung] with status, dates, and bemerkung.
  Future<void> updateRechnungFull({
    required int id,
    required String status,
    DateTime? bezahltAm,
    int? bemerkungId,
    String? bemerkungTitel,
    String? bemerkungText,
  }) async {
    await _db.transaction(() async {
      // Save or update bemerkung if provided
      int? newBemerkungId = bemerkungId;
      if (bemerkungTitel != null ||
          (bemerkungText != null && bemerkungText.isNotEmpty)) {
        if (bemerkungId != null) {
          // Update existing bemerkung
          newBemerkungId = await _bemerkungRepo.saveBemerkung(
            bemerkungId,
            bemerkungTitel ?? '',
            bemerkungText ?? '',
          );
        } else {
          // Create new bemerkung
          newBemerkungId = await _bemerkungRepo.saveBemerkung(
            null,
            bemerkungTitel ?? '',
            bemerkungText ?? '',
          );
        }
      }

      // Update rechnung
      await (_db.update(_db.rechnungen)..where((r) => r.id.equals(id))).write(
        RechnungenCompanion(
          status: Value(status),
          bezahltAm: Value(bezahltAm),
          bemerkungId: newBemerkungId != bemerkungId
              ? Value(newBemerkungId)
              : const Value.absent(),
          aktualisiertAm: Value(DateTime.now()),
        ),
      );
    });
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new Rechnung with its positions in a transaction.
  Future<int> addRechnung(
    RechnungenCompanion rechnung,
    List<RechnungPositionenCompanion> positionen,
  ) async {
    return await _db.transaction(() async {
      // Insert the rechnung
      final rechnungId = await _db.into(_db.rechnungen).insert(rechnung);

      // Insert all positions
      for (int i = 0; i < positionen.length; i++) {
        final position = positionen[i];
        await _db
            .into(_db.rechnungPositionen)
            .insert(
              RechnungPositionenCompanion(
                rechnungId: Value(rechnungId),
                positionNr: Value(i + 1),
                warenId: position.warenId,
                bezeichnung: position.bezeichnung,
                menge: position.menge,
                einzelpreisNetto: position.einzelpreisNetto,
                einzelpreisBrutto: position.einzelpreisBrutto,
                mwstSatz: position.mwstSatz,
                gesamtNetto: position.gesamtNetto,
                gesamtBrutto: position.gesamtBrutto,
              ),
            );
      }

      return rechnungId;
    });
  }

  /// Updates an existing [Rechnung].
  Future<void> updateRechnung(RechnungenCompanion rechnung) async {
    await (_db.update(
      _db.rechnungen,
    )..where((r) => r.id.equals(rechnung.id.value))).write(rechnung);
  }

  /// Updates only the status and bezahltAm of a [Rechnung].
  Future<void> updateRechnungStatus(
    int id,
    String status,
    DateTime? bezahltAm,
  ) async {
    await (_db.update(_db.rechnungen)..where((r) => r.id.equals(id))).write(
      RechnungenCompanion(
        status: Value(status),
        bezahltAm: Value(bezahltAm),
        aktualisiertAm: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a [Rechnung] and all its [RechnungPositionen] (via CASCADE).
  Future<int> deleteRechnung(int id) {
    return (_db.delete(_db.rechnungen)..where((r) => r.id.equals(id))).go();
  }

  // ── Positionen ────────────────────────────────────────────────────────────

  /// Updates the positions of a [Rechnung].
  /// Deletes all existing positions and inserts the new ones.
  Future<void> updatePositionen(
    int rechnungId,
    List<RechnungPositionenCompanion> positionen,
  ) async {
    await _db.transaction(() async {
      // Delete existing positions
      await (_db.delete(
        _db.rechnungPositionen,
      )..where((p) => p.rechnungId.equals(rechnungId))).go();

      // Insert new positions
      for (int i = 0; i < positionen.length; i++) {
        final position = positionen[i];
        await _db
            .into(_db.rechnungPositionen)
            .insert(
              position.copyWith(
                rechnungId: Value(rechnungId),
                positionNr: Value(i + 1),
              ),
            );
      }
    });
  }

  // ── Invoice Number Generation ─────────────────────────────────────────────

  /// Generates a unique invoice number with encoded date.
  /// Format: R-YYYY-XXXXX where XXXXX is a sequential number.
  /// Ensures the generated number is unique by checking against existing entries.
  Future<String> generateRechnungsnummer() async {
    final now = DateTime.now();
    final year = now.year;

    // Get the highest existing number for this year
    final result = await _db
        .customSelect(
          "SELECT MAX(CAST(substr(rechnungsnummer, 9) AS INTEGER)) as max_num "
          "FROM rechnung WHERE substr(rechnungsnummer, 3, 4) = ?",
          variables: [Variable<String>(year.toString())],
        )
        .getSingle();

    final maxNumber = (result.data['max_num'] as int?) ?? 0;
    int nextNumber = maxNumber + 1;

    // Ensure uniqueness (in case of gaps or manual insertions)
    String candidate = 'R-$year-${nextNumber.toString().padLeft(5, '0')}';
    while (await rechnungsnummerExists(candidate)) {
      nextNumber++;
      candidate = 'R-$year-${nextNumber.toString().padLeft(5, '0')}';
    }

    return candidate;
  }

  /// Checks if a rechnungsnummer already exists.
  Future<bool> rechnungsnummerExists(String rechnungsnummer) async {
    final result = await (_db.select(
      _db.rechnungen,
    )..where((r) => r.rechnungsnummer.equals(rechnungsnummer))).get();
    return result.isNotEmpty;
  }
}

/// Riverpod provider for [RechnungenRepository].
@riverpod
RechnungenRepository rechnungenRepository(Ref ref) {
  return RechnungenRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(bemerkungRepositoryProvider),
  );
}
