import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../data/master_data_repository.dart';
import '../../../core/database/database.dart' as db;
import 'master_data_dialog.dart';

class MasterDataScreen extends HookConsumerWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stammdaten'),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'Trainer'),
            Tab(text: 'Kursarten'),
            Tab(text: 'Orte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: const [
          _TrainersTab(),
          _CourseTypesTab(),
          _LocationsTab(),
        ],
      ),
    );
  }
}

class _TrainersTab extends HookConsumerWidget {
  const _TrainersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainersAsync = ref.watch(trainersRepositoryProvider);

    return trainersAsync.when(
      data: (trainers) => _MasterDataListView<db.Trainer>(
        items: trainers,
        getName: (t) => t.name,
        onAdd: () async {
          final name = await MasterDataDialog.show(context, title: 'Trainer hinzufügen');
          if (name != null) {
            ref.read(trainersRepositoryProvider.notifier).addTrainer(name);
          }
        },
        onEdit: (t) async {
          final name = await MasterDataDialog.show(context, title: 'Trainer bearbeiten', initialValue: t.name);
          if (name != null) {
            ref.read(trainersRepositoryProvider.notifier).updateTrainer(
              db.Trainer(id: t.id, name: name, isActive: t.isActive)
            );
          }
        },
        onDelete: (t) {
          ref.read(trainersRepositoryProvider.notifier).deleteTrainer(t.id);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Fehler: $e')),
    );
  }
}

class _CourseTypesTab extends HookConsumerWidget {
  const _CourseTypesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseTypesAsync = ref.watch(courseTypesRepositoryProvider);

    return courseTypesAsync.when(
      data: (courseTypes) => _MasterDataListView<db.CourseType>(
        items: courseTypes,
        getName: (c) => c.name,
        onAdd: () async {
          final name = await MasterDataDialog.show(context, title: 'Kursart hinzufügen');
          if (name != null) {
            ref.read(courseTypesRepositoryProvider.notifier).addCourseType(name);
          }
        },
        onEdit: (c) async {
          final name = await MasterDataDialog.show(context, title: 'Kursart bearbeiten', initialValue: c.name);
          if (name != null) {
            ref.read(courseTypesRepositoryProvider.notifier).updateCourseType(
              db.CourseType(id: c.id, name: name)
            );
          }
        },
        onDelete: (c) {
          ref.read(courseTypesRepositoryProvider.notifier).deleteCourseType(c.id);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Fehler: $e')),
    );
  }
}

class _LocationsTab extends HookConsumerWidget {
  const _LocationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsRepositoryProvider);

    return locationsAsync.when(
      data: (locations) => _MasterDataListView<db.Location>(
        items: locations,
        getName: (l) => l.name,
        onAdd: () async {
          final name = await MasterDataDialog.show(context, title: 'Ort hinzufügen');
          if (name != null) {
            ref.read(locationsRepositoryProvider.notifier).addLocation(name);
          }
        },
        onEdit: (l) async {
          final name = await MasterDataDialog.show(context, title: 'Ort bearbeiten', initialValue: l.name);
          if (name != null) {
            ref.read(locationsRepositoryProvider.notifier).updateLocation(
              db.Location(id: l.id, name: name)
            );
          }
        },
        onDelete: (l) {
          ref.read(locationsRepositoryProvider.notifier).deleteLocation(l.id);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Fehler: $e')),
    );
  }
}

class _MasterDataListView<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T) getName;
  final VoidCallback onAdd;
  final void Function(T) onEdit;
  final void Function(T) onDelete;

  const _MasterDataListView({
    required this.items,
    required this.getName,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Aktionen')),
                  ],
                  rows: items.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(getName(item))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => onEdit(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => onDelete(item),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
