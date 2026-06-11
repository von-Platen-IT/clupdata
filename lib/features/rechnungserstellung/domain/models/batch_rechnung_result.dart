/// Result of a batch invoice generation operation.
///
/// Returned by both [BeitraegeBatchService] and [VerkaufBatchService]
/// to provide a consistent result structure for the UI.
class BatchRechnungResult {
  /// Number of successfully created invoices.
  final int successCount;

  /// Number of members/entries that were skipped (e.g. already billed).
  final int skippedCount;

  /// Error messages collected during processing.
  final List<String> errors;

  /// Details of each successfully created invoice.
  final List<BatchRechnungEintrag> erstellteRechnungen;

  const BatchRechnungResult({
    required this.successCount,
    required this.skippedCount,
    required this.errors,
    this.erstellteRechnungen = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  int get totalProcessed => successCount + skippedCount;

  /// Total brutto sum of all created invoices.
  double get gesamtBetragBrutto =>
      erstellteRechnungen.fold(0, (sum, e) => sum + e.betragBrutto);
}

/// A single created invoice entry for result display.
class BatchRechnungEintrag {
  final String rechnungsnummer;
  final String kundeName;
  final double betragBrutto;

  const BatchRechnungEintrag({
    required this.rechnungsnummer,
    required this.kundeName,
    required this.betragBrutto,
  });
}

/// Internal data class holding member contract information.
/// Used by both batch services for member data access.
class MemberContractData {
  final int mitgliedId;
  final String name;
  final String vorname;
  final int leistungId;
  final String leistungName;
  final double bruttopreis;
  final int? mitgliedPreisId;
  final double? mitgliedBruttopreis;

  const MemberContractData({
    required this.mitgliedId,
    required this.name,
    required this.vorname,
    required this.leistungId,
    required this.leistungName,
    required this.bruttopreis,
    this.mitgliedPreisId,
    this.mitgliedBruttopreis,
  });

  /// The effective price for this member:
  /// member-specific price if available, otherwise leistung price.
  double get effectiveBruttopreis => mitgliedBruttopreis ?? bruttopreis;

  String get fullName => '$name, $vorname';
}
