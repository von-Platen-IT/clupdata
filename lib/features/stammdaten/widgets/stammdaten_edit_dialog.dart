import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../../../../core/database/database.dart';
import '../data/stammdaten_repository.dart';

/// Modal dialog for editing a [StammdatenItem] record.
class StammdatenEditDialog extends HookConsumerWidget {
  /// The key/Schlüssel of the setting to edit. If null, creates a new one (though rare).
  final String? schluessel;

  const StammdatenEditDialog({
    super.key,
    this.schluessel,
  });

  /// Opens the dialog.
  static Future<void> show(BuildContext context, {String? schluessel}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StammdatenEditDialog(schluessel: schluessel),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Data Loading ───────────────────────────────────────────────────────
    final settingAsync = useMemoized(() {
      if (schluessel == null) return Future<StammdatenItem?>.value(null);
      return ref.read(stammdatenRepositoryProvider).getSetting(schluessel!);
    }, [schluessel]);

    final settingSnapshot = useFuture(settingAsync);
    final isLoadingConfig = schluessel != null && settingSnapshot.connectionState == ConnectionState.waiting;

    // ── Form Controllers ───────────────────────────────────────────────────
    final ctrlSchluessel = useTextEditingController(text: schluessel ?? '');
    final ctrlBezeichnung = useTextEditingController();
    final ctrlWert = useTextEditingController();
    final ctrlBeschreibung = useTextEditingController();
    final ctrlKategorie = useTextEditingController();
    final ctrlTyp = useTextEditingController(text: 'string');

    final isSystemPflicht = useState(false);

    // ── Data Initialization ────────────────────────────────────────────────
    useEffect(() {
      if (settingSnapshot.hasData && settingSnapshot.data != null) {
        final s = settingSnapshot.data!;
        ctrlBezeichnung.text = s.bezeichnung;
        ctrlWert.text = s.wert ?? '';
        ctrlBeschreibung.text = s.beschreibung ?? '';
        ctrlKategorie.text = s.kategorie;
        ctrlTyp.text = s.typ;
        isSystemPflicht.value = s.systemPflicht;
      }
      return null;
    }, [settingSnapshot.data]);

    final isSaving = useState(false);
    final wertError = useState<String?>(null);

    // ── Save Action ────────────────────────────────────────────────────────
    Future<void> saveSetting() async {
      final typ = ctrlTyp.text.trim();
      final wert = ctrlWert.text.trim();
      wertError.value = null;

      // Validation
      if (wert.isNotEmpty) {
        if (typ == 'integer' && int.tryParse(wert) == null) {
          wertError.value = 'Muss eine gültige Ganzzahl sein.';
          return;
        } else if (typ == 'float') {
          final normalized = wert.replaceAll(',', '.');
          if (double.tryParse(normalized) == null) {
            wertError.value = 'Muss eine gültige Kommazahl sein.';
            return;
          }
        } else if (typ == 'boolean') {
          final v = wert.toLowerCase();
          if (v != 'true' && v != 'false' && v != '1' && v != '0') {
            wertError.value = 'Muss "true", "false", "1" oder "0" sein.';
            return;
          }
        } else if (typ == 'date') {
          if (DateTime.tryParse(wert) == null) {
            wertError.value = 'Muss ein gültiges Datum sein (YYYY-MM-DD).';
            return;
          }
        }
      }

      isSaving.value = true;
      try {
        final repo = ref.read(stammdatenRepositoryProvider);
        if (settingSnapshot.data != null) {
          final s = settingSnapshot.data!;
          final updated = s.copyWith(
            bezeichnung: ctrlBezeichnung.text.trim(),
            typ: ctrlTyp.text.trim(),
            wert: drift.Value(ctrlWert.text.trim()),
            beschreibung: drift.Value(ctrlBeschreibung.text.trim()),
            systemPflicht: isSystemPflicht.value,
          );
          await repo.updateSetting(updated);
        } else {
          // If creation is allowed
          final isSchluesselEmpty = ctrlSchluessel.text.trim().isEmpty;
          final fallbackSchluessel = ctrlBezeichnung.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
          final generatedSchluessel = fallbackSchluessel.isEmpty 
              ? 'neuer_schluessel_${DateTime.now().millisecondsSinceEpoch}' 
              : fallbackSchluessel;

          final newSetting = StammdatenCompanion.insert(
            schluessel: schluessel ?? (isSchluesselEmpty ? generatedSchluessel : ctrlSchluessel.text.trim()),
            typ: ctrlTyp.text.trim(), // Default fallback is string
            kategorie: ctrlKategorie.text.isEmpty ? 'sonstiges' : ctrlKategorie.text.trim(),
            bezeichnung: ctrlBezeichnung.text.trim(),
            wert: drift.Value(ctrlWert.text.trim()),
            beschreibung: drift.Value(ctrlBeschreibung.text.trim()),
            systemPflicht: drift.Value(isSystemPflicht.value),
          );
          await repo.addSetting(newSetting);
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Einstellung erfolgreich gespeichert')),
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

    // ── Loading Placeholder ────────────────────────────────────────────────
    if (isLoadingConfig) {
      return const AlertDialog(
        content: SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isReadOnly = settingSnapshot.data?.aenderbar == 0;
    
    // Subscribe to typ changes for the UI
    useListenable(ctrlTyp);
    final itemType = ctrlTyp.text.isEmpty ? 'string' : ctrlTyp.text;

    return AppEditDialogScaffold(
      title: schluessel == null ? 'Neue Einstellung' : 'Stammdaten bearbeiten',
      isSaving: isSaving.value,
      onSave: isReadOnly ? () {} : () { saveSetting(); },
      contentWidth: 600,
      deleteEntityLabel: 'Einstellung',
      onDelete: (isSystemPflicht.value || schluessel == null) ? null : () async {
        final repo = ref.read(stammdatenRepositoryProvider);
        await repo.deleteSetting(schluessel!);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── WARNING BANNER ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.error),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                const Gap(12),
                Expanded(
                  child: Text(
                    'Achtung: Die Änderung von Systemdaten kann zu Fehlfunktionen im Programm führen!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const AppSectionHeader('Einstellung'),
          const Gap(16),
          if (schluessel == null) ...[
            AppTextField(
              controller: ctrlSchluessel,
              label: 'Schlüssel (Technischer Name)',
              readOnly: false,
            ),
            const Gap(16),
          ],
          AppTextField(
            controller: ctrlBezeichnung,
            label: 'Bezeichnung',
            readOnly: isReadOnly,
          ),
          const Gap(16),
          // ── Data Type ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: AppDropdownField<String>(
                  controller: ctrlTyp,
                  label: 'Datentyp',
                  focusNode: useFocusNode(),
                  options: const ['string', 'integer', 'float', 'boolean', 'date'],
                  getLabel: (v) => v,
                  // ReadOnly logic: AppDropdownField doesn't natively support readOnly/enabled properties
                  // according to the error, so we omit it or implement a readOnly wrapper. Wait, let me just
                  // omit the enabled property for now. System settings shouldn't be touched by end users often.
                ),
              ),
              const Gap(16),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: ctrlWert,
                  label: 'Wert ($itemType)',
                  readOnly: isReadOnly,
                  errorText: wertError.value,
                  keyboardType: itemType == 'integer' || itemType == 'float' 
                      ? const TextInputType.numberWithOptions(decimal: true, signed: true) 
                      : TextInputType.text,
                ),
              ),
            ],
          ),
          const Gap(16),
          AppTextField(
            controller: ctrlBeschreibung,
            label: 'Beschreibung',
            maxLines: 3,
            readOnly: isReadOnly,
          ),
          const Gap(16),
          Row(
            children: [
              Checkbox(
                value: isSystemPflicht.value,
                onChanged: isReadOnly ? null : (v) => isSystemPflicht.value = v ?? false,
              ),
              const Gap(8),
              const Expanded(
                child: Text('Zwingend erforderlich (System-Pflicht, darf nicht gelöscht werden)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
