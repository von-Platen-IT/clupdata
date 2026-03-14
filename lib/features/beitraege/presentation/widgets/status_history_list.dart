import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../domain/models/beitrag_status.dart';
import 'status_badge.dart';

/// Displays a scrollable list of status history entries.
/// Used in BeitragEditDialog and potentially other places.
class StatusHistoryList extends StatelessWidget {
  final List<BeitragStatusVerlaufData> history;
  final DateFormat? dateFormatter;
  final double maxHeight;

  const StatusHistoryList({
    super.key,
    required this.history,
    this.dateFormatter,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = dateFormatter ?? DateFormat('dd.MM.yyyy');

    if (history.isEmpty) {
      return const Text('Keine Status-Historie vorhanden.');
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          final status = BeitragStatus.fromString(entry.status);
          final isLast = index == history.length - 1;

          return _HistoryEntryTile(
            entry: entry,
            status: status,
            dateFormatter: formatter,
            isLast: isLast,
          );
        },
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final BeitragStatusVerlaufData entry;
  final BeitragStatus status;
  final DateFormat dateFormatter;
  final bool isLast;

  const _HistoryEntryTile({
    required this.entry,
    required this.status,
    required this.dateFormatter,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: status.backgroundColor.withOpacityPercent(0.3),
        border: Border(
          bottom: !isLast
              ? BorderSide(color: Colors.grey.shade200)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          StatusBadge(
            status: status,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.bemerkung,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  dateFormatter.format(entry.geaendertAm),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
