import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'sort_column_config.dart';

class SortSettingsDialog extends HookWidget {
  final List<SortColumnConfig> initialConfigs;

  const SortSettingsDialog({
    super.key,
    required this.initialConfigs,
  });

  static Future<List<SortColumnConfig>?> show(
    BuildContext context, {
    required List<SortColumnConfig> initialConfigs,
  }) {
    return showDialog<List<SortColumnConfig>>(
      context: context,
      builder: (context) => SortSettingsDialog(
        initialConfigs: initialConfigs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Local copy of configs to allow cancellation
    final configs = useState<List<SortColumnConfig>>(
      initialConfigs.map((c) => c.copyWith()).toList()..sort((a, b) => a.priority.compareTo(b.priority)),
    );

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Sortierung'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Schließen',
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
              'Ziehen Sie Spalten in die gewünschte Reihenfolge. Aktivieren Sie per Checkbox.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: configs.value.length,
                onReorder: (int oldIndex, int newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = configs.value.removeAt(oldIndex);
                  configs.value.insert(newIndex, item);
                  
                  // Update priorities
                  for (var i = 0; i < configs.value.length; i++) {
                    configs.value[i].priority = i;
                  }
                  
                  // trigger rebuild
                  configs.value = List.from(configs.value);
                },
                itemBuilder: (context, index) {
                  final config = configs.value[index];
                  return Container(
                    key: ValueKey(config.field),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: config.enabled,
                        onChanged: (val) {
                          config.enabled = val ?? false;
                          configs.value = List.from(configs.value);
                        },
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
                            onPressed: config.enabled ? () {
                              config.ascending = !config.ascending;
                              configs.value = List.from(configs.value);
                            } : null,
                            tooltip: config.ascending ? 'Aufsteigend (klicken für absteigend)' : 'Absteigend (klicken für aufsteigend)',
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.drag_handle, color: Colors.grey),
                        ],
                      ),
                    ),
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
          onPressed: () {
            Navigator.of(context).pop(configs.value);
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
