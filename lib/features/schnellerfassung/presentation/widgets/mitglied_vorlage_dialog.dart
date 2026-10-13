import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/database/database.dart';
import '../../../members/data/members_repository.dart';

/// Dialog: Vorhandenes Mitglied suchen und als Vorlage übernehmen.
///
/// Liefert das ausgewählte [Mitglied] zurück; die Feldübernahme
/// (inkl. Leeren der Personenfelder) übernimmt der Aufrufer.
class MitgliedVorlageDialog extends HookConsumerWidget {
  const MitgliedVorlageDialog({super.key});

  /// Opens the dialog and returns the selected member (or `null`).
  static Future<Mitglied?> show(BuildContext context) {
    return showDialog<Mitglied>(
      context: context,
      builder: (_) => const MitgliedVorlageDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final ergebnisse = useState<List<Mitglied>>([]);

    Future<void> suchen(String query) async {
      final repo = ref.read(membersRepositoryProvider);
      ergebnisse.value = query.trim().length < 2
          ? await repo.getAllMembers()
          : await repo.searchMembers(query);
    }

    useEffect(() {
      suchen('');
      return null;
    }, []);

    return AlertDialog(
      title: const Text('Von vorhandenem Datensatz übernehmen'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            AppTextField(
              controller: searchController,
              label: 'Mitglied suchen',
              suffixIcon: const Icon(Icons.search),
              onChanged: suchen,
            ),
            const Gap(8),
            Expanded(
              child: ergebnisse.value.isEmpty
                  ? const Center(child: Text('Keine Mitglieder gefunden.'))
                  : ListView(
                      children: [
                        for (final m in ergebnisse.value.take(50))
                          ListTile(
                            dense: true,
                            title: Text('${m.name}, ${m.vorname}'),
                            subtitle: Text('${m.plz ?? ''} ${m.ort ?? ''}'),
                            onTap: () => Navigator.of(context).pop(m),
                          ),
                      ],
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
      ],
    );
  }
}
