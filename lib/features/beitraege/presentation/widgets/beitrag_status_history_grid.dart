import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../widgets/data_grid_v2/vpit_data_grid.dart';
import '../../../../widgets/data_grid_v2/data_grid_column_config.dart';
import '../../domain/models/beitrag_status.dart';
import '../../domain/models/beitrag_status_history_row_data.dart';
import '../widgets/status_badge.dart';

/// Displays the status history for a Beitrag using [VpitDataGrid].
///
/// This widget replaces the previous [StatusHistoryList] and provides
/// a tabular view with columns: Status, Datum, Grund.
///
/// The status value for each row is taken directly from the history entry,
/// NOT from the current Beitrag record.
class BeitragStatusHistoryGrid extends HookConsumerWidget {
  /// The list of history entries to display.
  final List<BeitragStatusHistoryRowData> history;

  /// Date formatter for the datum column.
  final DateFormat dateFormatter;

  /// Maximum height for the grid container.
  final double maxHeight;

  const BeitragStatusHistoryGrid({
    super.key,
    required this.history,
    required this.dateFormatter,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Empty state
    if (history.isEmpty) {
      return const Text('Keine Status-Historie vorhanden.');
    }

    // Column configurations per structur.md requirements
    final columns = useMemoized<
      List<DataGridColumnConfig<BeitragStatusHistoryRowData>>
    >(() {
      return [
        DataGridColumnConfig<BeitragStatusHistoryRowData>(
          field: 'status',
          title: 'Status',
          valueExtractor: (row) => row.status,
          type: PlutoColumnType.text(),
          renderer: (PlutoColumnRendererContext rendererContext) {
            final statusValue = rendererContext.cell.value as String? ?? '';
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: StatusBadge.fromString(statusValue),
            );
          },
          sortable: true,
          filterable: true,
        ),
        DataGridColumnConfig<BeitragStatusHistoryRowData>(
          field: 'geaendert_am',
          title: 'Datum',
          valueExtractor: (row) => dateFormatter.format(row.geaendertAm),
          type: PlutoColumnType.text(),
          sortable: true,
          filterable: true,
        ),
        DataGridColumnConfig<BeitragStatusHistoryRowData>(
          field: 'bemerkung',
          title: 'Grund',
          valueExtractor: (row) => row.bemerkung,
          type: PlutoColumnType.text(),
          sortable: true,
          filterable: true,
        ),
      ];
    }, [dateFormatter]);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: VpitDataGrid<BeitragStatusHistoryRowData>(
        items: history,
        columnConfigs: columns,
        toSearchString: (row) {
          final status = BeitragStatus.fromString(row.status);
          return [
            status.label,
            row.status,
            dateFormatter.format(row.geaendertAm),
            row.bemerkung,
          ].join(' ').toLowerCase();
        },
        toJson: (row) => row.toJson(),
        fromJson: BeitragStatusHistoryRowData.fromJson,
        rowBgColorResolver: (row) {
          final status = BeitragStatus.fromString(row.status);
          return status.backgroundColor.withValues(alpha: 0.15);
        },
      ),
    );
  }
}
