import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/database/database.dart';
import 'presentation/members_controller.dart';
import 'presentation/add_member_dialog.dart';

/// The main view for managing club members.
///
/// This screen displays a [DataTable] containing all members (active and inactive)
/// fetched real-time from the database via [membersStreamProvider].
/// It allows users to view member details, deactivate members, and open the
/// [AddMemberDialog] to register new members.
class MembersScreen extends ConsumerWidget {
  /// Creates the members screen.
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitglieder'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AddMemberDialog(),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Neues Mitglied'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Fehler: $error')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text('Noch keine Mitglieder vorhanden. Füge dein erstes Mitglied hinzu!'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Vorname')),
                      DataColumn(label: Text('Nachname')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Aktionen')),
                    ],
                    rows: members.map((member) {
                      return DataRow(
                        cells: [
                          DataCell(Text('#${member.id}')),
                          DataCell(Text(member.firstName)),
                          DataCell(Text(member.lastName)),
                          DataCell(
                            Chip(
                              label: Text(member.isActive ? 'Aktiv' : 'Inaktiv'),
                              backgroundColor: member.isActive 
                                ? Colors.green.withValues(alpha: 0.1) 
                                : Colors.red.withValues(alpha: 0.1),
                              labelStyle: TextStyle(
                                color: member.isActive ? Colors.green[800] : Colors.red[800]
                              ),
                              side: BorderSide.none,
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    // TODO: Edit Member Feature
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Bearbeiten kommt in einem späteren Update'))
                                    );
                                  }
                                ),
                                if (member.isActive)
                                  IconButton(
                                    icon: const Icon(Icons.person_off, size: 20, color: Colors.deepOrange),
                                    tooltip: 'Deaktivieren',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Mitglied deaktivieren?'),
                                          content: Text('${member.firstName} ${member.lastName} wirklich deaktivieren?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
                                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Deaktivieren')),
                                          ],
                                        )
                                      );
                                      if (confirm == true) {
                                        ref.read(membersActionsProvider.notifier).deactivateMember(member.id);
                                      }
                                    }
                                  )
                              ],
                            )
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
