import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'sort_column_config.dart';

/// Modal dialog for configuring the multi-column sort chain.
///
/// Uses a [ReorderableListView] to allow drag-and-drop priority ordering.
/// Each column can be enabled/disabled via checkbox and toggled between
/// ascending/descending sort direction.
class SortSettingsDialog extends HookWidget {
  /// The initial sort configurations to display and modify.
  final List<SortColumnConfig> initialConfigs;

  const SortSettingsDialog({
    super.key,
    required this.initialConfigs,
  });

  /// Opens the sort settings dialog and returns the updated
  /// [List<SortColumnConfig>] or `null` if the user cancelled.
  static Future<List<SortColumnConfig>?> show(
    BuildContext context, {
    required List<SortColumnConfig> initialConfigs,
  }) {
    return showDialog<List<SortColumnConfig>>(
      context: context,
      builder: (context) =>
          SortSettingsDialog(initialConfigs: initialConfigs),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Local deep copy — changes are only applied on "Übernehmen"
    final configs = useState<List<SortColumnConfig>>(
      initialConfigs
          .map((c) => c.copyWith())
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority)),
    );

    /// Rebuilds the list immutably using [copyWith] to update [priority]
    /// fields after a drag-and-drop reorder.
    void applyReorder(int oldIndex, int newIndex) {
      if (oldIndex < newIndex) newIndex -= 1;
      final updated = List<SortColumnConfig>.from(configs.value);
      final moved = updated.removeAt(oldIndex);
      updated.insert(newIndex, moved);
      configs.value = [
        for (var i = 0; i < updated.length; i++)
          updated[i].copyWith(priority: i),
      ];
    }

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Sortierung'),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ziehen Sie Spalten in die gewünschte Reihenfolge und aktivieren Sie per Checkbox.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: configs.value.length,
                onReorder: applyReorder,
                itemBuilder: (context, index) {
                  final config = configs.value[index];
                  return _SortConfigTile(
                    key: ValueKey(config.field),
                    config: config,
                    onToggleEnabled: (val) {
                      configs.value = [
                        for (final c in configs.value)
                          if (c.field == config.field)
                            c.copyWith(enabled: val)
                          else
                            c,
                      ];
                    },
                    onToggleAscending: () {
                      configs.value = [
                        for (final c in configs.value)
                          if (c.field == config.field)
                            c.copyWith(ascending: !c.ascending)
                          else
                            c,
                      ];
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(configs.value),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

/// A single row in the sort configuration list.
class _SortConfigTile extends StatelessWidget {
  final SortColumnConfig config;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onToggleAscending;

  const _SortConfigTile({
    super.key,
    required this.config,
    required this.onToggleEnabled,
    required this.onToggleAscending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        leading: Checkbox(
          value: config.enabled,
          onChanged: (val) => onToggleEnabled(val ?? false),
        ),
        title: Text(config.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                config.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 20,
                color: config.enabled ? null : Colors.grey.shade400,
              ),
              tooltip: config.ascending
                  ? 'Aufsteigend (klicken für absteigend)'
                  : 'Absteigend (klicken für aufsteigend)',
              onPressed: config.enabled ? onToggleAscending : null,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
