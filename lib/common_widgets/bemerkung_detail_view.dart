import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:clupdata/core/database/database.dart';
import 'app_section_header.dart';
import 'forms/app_text_field.dart';

/// A reusable panel to display and edit a [Bemerkung] for any selected entity.
/// Typically placed at the bottom of a [FeatureScreenScaffold].
class BemerkungDetailView extends HookWidget {
  final BemerkungData? bemerkung;
  final String entityName;
  final Future<void> Function(String titel, String text) onSave;

  const BemerkungDetailView({
    super.key,
    required this.bemerkung,
    required this.entityName,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final ctrlTitel = useTextEditingController(text: bemerkung?.titel ?? '');
    final ctrlText = useTextEditingController(text: bemerkung?.textValue ?? '');
    
    // Reset controllers when a different bemerkung is selected
    useEffect(() {
      ctrlTitel.text = bemerkung?.titel ?? '';
      ctrlText.text = bemerkung?.textValue ?? '';
      return null;
    }, [bemerkung]);

    final isSaving = useState(false);

    Future<void> handleSave() async {
      isSaving.value = true;
      try {
        await onSave(ctrlTitel.text.trim(), ctrlText.text.trim());
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bemerkung gespeichert')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Speichern: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSectionHeader('Bemerkung für ausgewählte(s) $entityName'),
                FilledButton.icon(
                  onPressed: isSaving.value ? null : handleSave,
                  icon: isSaving.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Speichern'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const Gap(16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: AppTextField(
                    controller: ctrlTitel,
                    label: 'Titel',
                  ),
                ),
                const Gap(16),
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    controller: ctrlText,
                    label: 'Text',
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
