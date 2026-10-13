import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/database/database.dart';
import '../../../members/data/members_repository.dart';
import '../providers/rechnungslegung_wizard_provider.dart';

/// Wizard-Schritt 2 (Mitglieder-Modi): Suche und Auswahl von Mitgliedern.
///
/// [multi] = `false` → Einzelmitglied (Radio-Auswahl),
/// [multi] = `true` → Mehrfachauswahl (Checkboxen).
class MitgliedAuswahl extends HookConsumerWidget {
  final bool multi;

  const MitgliedAuswahl({super.key, required this.multi});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    final notifier = ref.read(rechnungslegungWizardProvider.notifier);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: searchController,
          label: 'Mitglied suchen',
          suffixIcon: const Icon(Icons.search),
          onChanged: suchen,
        ),
        const Gap(8),
        Text(
          multi
              ? 'Ausgewählt: ${state.mitgliedIds.length} Mitglied(er)'
              : (state.mitgliedIds.isEmpty
                    ? 'Kein Mitglied ausgewählt'
                    : '1 Mitglied ausgewählt'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Gap(4),
        for (final m in ergebnisse.value.take(50))
          multi
              ? CheckboxListTile(
                  value: state.mitgliedIds.contains(m.id),
                  onChanged: (_) => notifier.toggleMitglied(m.id),
                  title: Text('${m.name}, ${m.vorname}'),
                  subtitle: Text('${m.plz} ${m.ort}'),
                  dense: true,
                )
              : RadioListTile<int>(
                  value: m.id,
                  groupValue: state.mitgliedIds.isEmpty
                      ? null
                      : state.mitgliedIds.first,
                  onChanged: (_) => notifier.setMitglieder([m.id]),
                  title: Text('${m.name}, ${m.vorname}'),
                  subtitle: Text('${m.plz} ${m.ort}'),
                  dense: true,
                ),
      ],
    );
  }
}
