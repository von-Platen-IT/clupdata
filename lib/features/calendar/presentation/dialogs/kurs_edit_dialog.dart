import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../data/kursplan_repository.dart';
import '../../domain/models/kurs_row_data.dart';
import '../kurs_farbe_utils.dart';

/// Dialog zum Anlegen/Bearbeiten eines Kurses (Kurstyp).
class KursEditDialog extends HookConsumerWidget {
  /// Bestehender Kurs; `null` = neuer Kurs.
  final KursRowData? kurs;

  const KursEditDialog({super.key, this.kurs});

  /// Opens the dialog. Pass [kurs] to edit, omit it to create.
  static Future<void> show(BuildContext context, {KursRowData? kurs}) {
    return showDialog(
      context: context,
      builder: (_) => KursEditDialog(kurs: kurs),
    );
  }

  /// Vordefinierte Farbpalette für die Kurs-Kennzeichnung.
  static const List<String> farbPalette = [
    '#FFCDD2',
    '#F8BBD0',
    '#E1BEE7',
    '#C5CAE9',
    '#BBDEFB',
    '#B2EBF2',
    '#C8E6C9',
    '#FFF9C4',
    '#FFE0B2',
    '#FFCCBC',
    '#D7CCC8',
    '#CFD8DC',
    '#A5D6A7',
    '#90CAF9',
    '#CE93D8',
    '#EF9A9A',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: kurs?.name ?? '');
    final sportartController = useTextEditingController(
      text: kurs?.kampfsportart ?? '',
    );
    final farbe = useState<String>(kurs?.farbe ?? farbPalette.first);
    final isSaving = useState(false);
    final errorText = useState<String?>(null);

    Future<void> speichern() async {
      final name = nameController.text.trim();
      final sportart = sportartController.text.trim();
      if (name.isEmpty || sportart.isEmpty) {
        errorText.value = 'Name und Kampfsportart sind Pflichtfelder.';
        return;
      }
      isSaving.value = true;
      try {
        final repo = ref.read(kursplanRepositoryProvider);
        if (kurs == null) {
          await repo.createKurs(
            name: name,
            kampfsportart: sportart,
            farbe: farbe.value,
          );
        } else {
          await repo.updateKurs(
            kurs!.copyWith(
              name: name,
              kampfsportart: sportart,
              farbe: farbe.value,
            ),
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      } finally {
        isSaving.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: kurs == null ? 'Neuer Kurs' : 'Kurs bearbeiten',
      contentWidth: 420,
      isSaving: isSaving.value,
      onSave: speichern,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorText.value != null) ...[
            Text(
              errorText.value!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const Gap(8),
          ],
          AppTextField(
            controller: nameController,
            label: 'Name',
            required: true,
          ),
          const Gap(12),
          AppTextField(
            controller: sportartController,
            label: 'Kampfsportart',
            required: true,
          ),
          const Gap(12),
          Text('Farbe', style: Theme.of(context).textTheme.labelLarge),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in farbPalette)
                GestureDetector(
                  onTap: () => farbe.value = hex,
                  child: Tooltip(
                    message: hex,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: parseKursFarbe(hex),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: farbe.value == hex
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: farbe.value == hex ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Gap(8),
          Text(
            'Ausgewählt: ${farbe.value}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
