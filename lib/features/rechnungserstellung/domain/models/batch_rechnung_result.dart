/// Result of a batch invoice generation operation.
///
/// Returned by `AbrechnungService` to provide a consistent result
/// structure for the UI.
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

  /// Database id of the created `beitrag` (e.g. for follow-up exports).
  final int? beitragId;

  const BatchRechnungEintrag({
    required this.rechnungsnummer,
    required this.kundeName,
    required this.betragBrutto,
    this.beitragId,
  });
}
