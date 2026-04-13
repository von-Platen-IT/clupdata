import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/core/providers/database_provider.dart';

part 'bemerkung_repository.g.dart';

/// Central repository for all Bemerkung (note/remark) database operations.
///
/// This repository eliminates the duplicated saveBemerkung logic that was
/// previously spread across 5 feature repositories (Members, Waren,
/// Leistungen, Beitraege, Rechnungen).
class BemerkungRepository {
  final AppDatabase _db;

  BemerkungRepository(this._db);

  /// Saves a Bemerkung (insert or update) and returns the ID.
  ///
  /// If [existingId] is provided, the existing record is updated.
  /// Otherwise, a new record is inserted.
  Future<int> saveBemerkung(int? existingId, String titel, String text) async {
    if (existingId != null) {
      await (_db.update(
        _db.bemerkung,
      )..where((b) => b.id.equals(existingId))).write(
        BemerkungCompanion(titel: Value(titel), textValue: Value(text)),
      );
      return existingId;
    } else {
      return _db
          .into(_db.bemerkung)
          .insert(
            BemerkungCompanion.insert(titel: titel, textValue: Value(text)),
          );
    }
  }

  /// Saves a Bemerkung only if title or text is non-empty.
  ///
  /// Returns the new or existing ID, or the original [existingId] if
  /// both [titel] and [text] are empty (no save performed).
  Future<int?> saveBemerkungIfContent(
    int? existingId,
    String titel,
    String text,
  ) async {
    if (titel.isEmpty && text.isEmpty) return existingId;
    return saveBemerkung(existingId, titel, text);
  }

  /// Gets a Bemerkung by its ID.
  Future<BemerkungData?> getBemerkungById(int id) {
    return (_db.select(
      _db.bemerkung,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
  }
}

/// Riverpod provider for [BemerkungRepository].
@riverpod
BemerkungRepository bemerkungRepository(Ref ref) {
  return BemerkungRepository(ref.watch(appDatabaseProvider));
}
