import 'package:clupdata/core/database/database.dart';

/// View model for a single status history entry in the Beitragsdialog.
///
/// This model maps directly from [BeitragStatusVerlaufData] and is used
/// by the [VpitDataGrid] in the status history display.
///
/// Important: The status is taken directly from the history entry,
/// NOT from the current Beitrag record.
class BeitragStatusHistoryRowData {
  /// Primary key from the history table.
  final int id;

  /// The status value at the time of this history entry.
  /// Taken directly from beitrag_status_verlauf.status.
  final String status;

  /// The timestamp when this status was set.
  final DateTime geaendertAm;

  /// The reason/explanation for this status change.
  final String bemerkung;

  const BeitragStatusHistoryRowData({
    required this.id,
    required this.status,
    required this.geaendertAm,
    required this.bemerkung,
  });

  /// Creates a [BeitragStatusHistoryRowData] from a [BeitragStatusVerlaufData].
  factory BeitragStatusHistoryRowData.fromVerlauf(
    BeitragStatusVerlaufData verlauf,
  ) {
    return BeitragStatusHistoryRowData(
      id: verlauf.id,
      status: verlauf.status,
      geaendertAm: verlauf.geaendertAm,
      bemerkung: verlauf.bemerkung,
    );
  }

  /// Serializes to JSON for DataGrid export.
  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'geaendertAm': geaendertAm.toIso8601String(),
        'bemerkung': bemerkung,
      };

  /// Deserializes from JSON.
  static BeitragStatusHistoryRowData fromJson(Map<String, dynamic> json) {
    return BeitragStatusHistoryRowData(
      id: json['id'] as int,
      status: json['status'] as String,
      geaendertAm: DateTime.parse(json['geaendertAm'] as String),
      bemerkung: json['bemerkung'] as String,
    );
  }
}
