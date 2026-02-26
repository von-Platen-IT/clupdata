import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'sort_column_config.dart';

class SortSettingsDialog extends HookWidget {
  final List<SortColumnConfig> initialConfig;

  const SortSettingsDialog({super.key, required this.initialConfig});

  @override
  Widget build(BuildContext context) {
    // Deep copy the config to allow local modification without affecting the parent
    // until "Übernehmen" is clicked.
    final configState = useState<List<SortColumnConfig>>(
      initialConfig.map((c) => SortColumnConfig(
        field: c.field,
        label: c.label,
        enabled: c.enabled,
        ascending: c.ascending,
        priority: c.priority,
      )).toList()..sort((a, b) => a.priority.compareTo(b.priority)),
    );

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Sortierung'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ziehen Sie Spalten in die gewünschte Reihenfolge. Aktivieren Sie per Checkbox.',
              style: TextStyle(fontSize: 14),
            ),
            const Gap(16),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: configState.value.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final newConfig = List<SortColumnConfig>.from(configState.value);
                  final item = newConfig.removeAt(oldIndex);
                  newConfig.insert(newIndex, item);
                  
                  // Update priorities
                  for (int i = 0; i < newConfig.length; i++) {
                    newConfig[i].priority = i;
                  }
                  
                  configState.value = newConfig;
                },
                itemBuilder: (context, index) {
                  final item = configState.value[index];
                  return Container(
                    key: ValueKey(item.field),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: item.enabled,
                        onChanged: (val) {
                          final newConfig = List<SortColumnConfig>.from(configState.value);
                          newConfig[index].enabled = val ?? false;
                          configState.value = newConfig;
                        },
                      ),
                      title: Text(item.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              item.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 20,
                            ),
                            onPressed: () {
                              final newConfig = List<SortColumnConfig>.from(configState.value);
                              newConfig[index].ascending = !newConfig[index].ascending;
                              configState.value = newConfig;
                            },
                            tooltip: item.ascending ? 'Aufsteigend' : 'Absteigend',
                          ),
                          const Gap(8),
                          const Icon(Icons.drag_handle),
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
          onPressed: () => Navigator.of(context).pop(configState.value),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
