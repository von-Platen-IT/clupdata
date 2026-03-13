import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../members/data/members_repository.dart';
import '../../waren/data/waren_repository.dart';
import '../data/rechnungen_repository.dart';

/// Position data for editing in the dialog.
class PositionEingabe {
  WarenItem? ware;
  String bezeichnung;
  double menge;
  double einzelpreisNetto;
  double einzelpreisBrutto;
  double mwstSatz;

  PositionEingabe({
    this.ware,
    this.bezeichnung = '',
    this.menge = 1,
    this.einzelpreisNetto = 0,
    this.einzelpreisBrutto = 0,
    this.mwstSatz = 19,
  });

  double get gesamtNetto => menge * einzelpreisNetto;
  double get gesamtBrutto => menge * einzelpreisBrutto;
}

/// Dialog for creating a new Rechnung.
class NeueRechnungDialog extends HookConsumerWidget {
  const NeueRechnungDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NeueRechnungDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final currencyFormatter = NumberFormat.currency(
      locale: 'de_DE',
      symbol: '€',
    );
    final db = ref.watch(appDatabaseProvider);

    final isSaving = useState(false);
    final rechnungsnummer = useState<String>('');
    final selectedMember = useState<Mitglied?>(null);

    final memberSearchController = useTextEditingController();
    final kundeNameController = useTextEditingController();
    final wareSearchController = useTextEditingController();
    final rechnungsnummerController = useTextEditingController();

    final rechnungsDatum = useState<DateTime>(DateTime.now());
    final faelligkeitDatum = useState<DateTime>(
      DateTime.now().add(const Duration(days: 14)),
    );

    final positionen = useState<List<PositionEingabe>>([]);
    final memberSearchResults = useState<List<Mitglied>>([]);
    final warenSearchResults = useState<List<WarenItem>>([]);
    final showMemberSearch = useState<bool>(false);
    final showWarenSearch = useState<bool>(false);
    final isLoadingInvoiceNumber = useState(true);

    // Calculated totals
    final gesamtNetto = useMemoized(
      () =>
          positionen.value.fold<double>(0, (sum, pos) => sum + pos.gesamtNetto),
      [positionen.value],
    );
    final gesamtMwst = useMemoized(
      () => positionen.value.fold<double>(
        0,
        (sum, pos) => sum + (pos.gesamtBrutto - pos.gesamtNetto),
      ),
      [positionen.value],
    );
    final gesamtBrutto = useMemoized(
      () => positionen.value.fold<double>(
        0,
        (sum, pos) => sum + pos.gesamtBrutto,
      ),
      [positionen.value],
    );

    useEffect(() {
      Future<void> init() async {
        final repo = ref.read(rechnungenRepositoryProvider);
        rechnungsnummer.value = await repo.generateRechnungsnummer();
        rechnungsnummerController.text = rechnungsnummer.value;
        isLoadingInvoiceNumber.value = false;
      }

      init();
      return null;
    }, []);

    Future<void> searchMembers(String query) async {
      if (query.length < 2) {
        memberSearchResults.value = [];
        return;
      }
      final repo = ref.read(membersRepositoryProvider);
      final results = await repo.searchMembers(query);
      memberSearchResults.value = results;
    }

    Future<void> loadAllMembers() async {
      final repo = ref.read(membersRepositoryProvider);
      final results = await repo.getAllMembers();
      memberSearchResults.value = results;
    }

    Future<void> searchWaren(String query) async {
      if (query.length < 2) {
        warenSearchResults.value = [];
        return;
      }
      final repo = ref.read(warenRepositoryProvider);
      final results = await repo.searchWaren(query);
      warenSearchResults.value = results;
    }

    Future<void> loadAllWaren() async {
      final repo = ref.read(warenRepositoryProvider);
      final results = await repo.getAllWaren();
      warenSearchResults.value = results;
    }

    void updatePosition(int index, PositionEingabe updated) {
      final newList = List<PositionEingabe>.from(positionen.value);
      newList[index] = updated;
      positionen.value = newList;
    }

    void removePosition(int index) {
      final newList = List<PositionEingabe>.from(positionen.value);
      newList.removeAt(index);
      positionen.value = newList;
    }

    void addPosition(WarenItem ware) {
      // Prüfe ob das Produkt bereits im Warenkorb ist
      final existingIndex = positionen.value.indexWhere(
        (pos) => pos.ware?.id == ware.id,
      );

      if (existingIndex >= 0) {
        // Produkt existiert bereits - erhöhe Menge um 1
        final existingPos = positionen.value[existingIndex];
        final updatedPos = PositionEingabe(
          ware: existingPos.ware,
          bezeichnung: existingPos.bezeichnung,
          menge: existingPos.menge + 1,
          einzelpreisNetto: existingPos.einzelpreisNetto,
          einzelpreisBrutto: existingPos.einzelpreisBrutto,
          mwstSatz: existingPos.mwstSatz,
        );
        updatePosition(existingIndex, updatedPos);
      } else {
        // Neues Produkt - füge neue Position hinzu
        // Berechne Nettopreis aus Brutto (Annahme: 19% MwSt)
        final mwstSatz = 19.0;
        final brutto = ware.bruttopreis;
        final netto = brutto / (1 + mwstSatz / 100);

        final newPos = PositionEingabe(
          ware: ware,
          bezeichnung: ware.bezeichnung,
          menge: 1,
          einzelpreisNetto: netto,
          einzelpreisBrutto: brutto,
          mwstSatz: mwstSatz,
        );

        positionen.value = [...positionen.value, newPos];
      }

      wareSearchController.clear();
      warenSearchResults.value = [];
      showWarenSearch.value = false;
    }

    void increaseQuantity(int index) {
      final pos = positionen.value[index];
      final updatedPos = PositionEingabe(
        ware: pos.ware,
        bezeichnung: pos.bezeichnung,
        menge: pos.menge + 1,
        einzelpreisNetto: pos.einzelpreisNetto,
        einzelpreisBrutto: pos.einzelpreisBrutto,
        mwstSatz: pos.mwstSatz,
      );
      updatePosition(index, updatedPos);
    }

    void decreaseQuantity(int index) {
      final pos = positionen.value[index];
      final newMenge = pos.menge - 1;

      if (newMenge <= 0) {
        // Bei Menge 0 oder weniger: Position entfernen
        removePosition(index);
      } else {
        final updatedPos = PositionEingabe(
          ware: pos.ware,
          bezeichnung: pos.bezeichnung,
          menge: newMenge,
          einzelpreisNetto: pos.einzelpreisNetto,
          einzelpreisBrutto: pos.einzelpreisBrutto,
          mwstSatz: pos.mwstSatz,
        );
        updatePosition(index, updatedPos);
      }
    }

    Future<void> saveRechnung() async {
      if (selectedMember.value == null &&
          kundeNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bitte wählen Sie ein Mitglied aus oder geben Sie einen Kundennamen ein.',
            ),
          ),
        );
        return;
      }
      if (positionen.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte fügen Sie mindestens eine Position hinzu.'),
          ),
        );
        return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(rechnungenRepositoryProvider);

        final positionCompanions = positionen.value.asMap().entries.map((
          entry,
        ) {
          final index = entry.key;
          final pos = entry.value;
          return RechnungPositionenCompanion(
            rechnungId: const drift.Value.absent(),
            positionNr: drift.Value(index + 1),
            warenId: pos.ware != null
                ? drift.Value(pos.ware!.id)
                : const drift.Value.absent(),
            bezeichnung: drift.Value(pos.bezeichnung),
            menge: drift.Value(pos.menge),
            einzelpreisNetto: drift.Value(pos.einzelpreisNetto),
            einzelpreisBrutto: drift.Value(pos.einzelpreisBrutto),
            mwstSatz: drift.Value(pos.mwstSatz),
            gesamtNetto: drift.Value(pos.gesamtNetto),
            gesamtBrutto: drift.Value(pos.gesamtBrutto),
          );
        }).toList();

        await repo.addRechnung(
          RechnungenCompanion.insert(
            rechnungsnummer: rechnungsnummer.value,
            mitgliedId: selectedMember.value != null
                ? drift.Value(selectedMember.value!.id)
                : const drift.Value.absent(),
            kundeName: selectedMember.value == null
                ? drift.Value(kundeNameController.text.trim())
                : const drift.Value.absent(),
            status: 'offen',
            datum: rechnungsDatum.value,
            faelligAm: faelligkeitDatum.value,
            betragNetto: gesamtNetto,
            betragBrutto: gesamtBrutto,
            betragMwst: gesamtMwst,
          ),
          positionCompanions,
        );

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rechnung erfolgreich erstellt')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Erstellen: $e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: 'Neue Rechnung',
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoadingInvoiceNumber.value)
              const Center(child: CircularProgressIndicator())
            else
              AppTextField(
                controller: rechnungsnummerController,
                label: 'Rechnungsnummer',
                readOnly: true,
              ),
            const Gap(16),

            const AppSectionHeader('Kunde'),
            const Gap(8),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showMemberSearch.value = true;
                      loadAllMembers();
                    },
                    child: AbsorbPointer(
                      child: AppTextField(
                        controller: memberSearchController,
                        label: 'Mitglied suchen...',
                        suffixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Alle Mitglieder anzeigen',
                  onPressed: () {
                    showMemberSearch.value = true;
                    loadAllMembers();
                  },
                ),
                if (selectedMember.value != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Auswahl löschen',
                    onPressed: () {
                      selectedMember.value = null;
                      memberSearchController.clear();
                      kundeNameController.clear();
                    },
                  ),
              ],
            ),

            if (showMemberSearch.value)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Suchen...',
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: searchMembers,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: memberSearchResults.value.length,
                        itemBuilder: (context, index) {
                          final member = memberSearchResults.value[index];
                          return ListTile(
                            dense: true,
                            title: Text('${member.name}, ${member.vorname}'),
                            onTap: () {
                              selectedMember.value = member;
                              memberSearchController.text =
                                  '${member.name}, ${member.vorname}';
                              kundeNameController.text =
                                  '${member.name}, ${member.vorname}';
                              showMemberSearch.value = false;
                            },
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () => showMemberSearch.value = false,
                      child: const Text('Schließen'),
                    ),
                  ],
                ),
              ),

            if (selectedMember.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text(
                    '${selectedMember.value!.name}, ${selectedMember.value!.vorname}',
                  ),
                  onDeleted: () {
                    selectedMember.value = null;
                    memberSearchController.clear();
                    kundeNameController.clear();
                  },
                ),
              ),

            if (selectedMember.value == null) ...[
              const Gap(8),
              AppTextField(
                controller: kundeNameController,
                label: 'Kundenname (falls kein Mitglied)',
              ),
            ],
            const Gap(24),

            const AppSectionHeader('Daten'),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: AppDatePickerField(
                    value: rechnungsDatum.value,
                    onChanged: (date) {
                      if (date != null) rechnungsDatum.value = date;
                    },
                    label: 'Rechnungsdatum',
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: AppDatePickerField(
                    value: faelligkeitDatum.value,
                    onChanged: (date) {
                      if (date != null) faelligkeitDatum.value = date;
                    },
                    label: 'Fällig am',
                  ),
                ),
              ],
            ),
            const Gap(24),

            const AppSectionHeader('Positionen'),
            const Gap(8),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showWarenSearch.value = true;
                      loadAllWaren();
                    },
                    child: AbsorbPointer(
                      child: AppTextField(
                        controller: wareSearchController,
                        label: 'Artikel suchen...',
                        suffixIcon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                const Gap(8),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Alle Artikel anzeigen',
                  onPressed: () {
                    showWarenSearch.value = true;
                    loadAllWaren();
                  },
                ),
              ],
            ),

            if (showWarenSearch.value)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Suchen...',
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: searchWaren,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: warenSearchResults.value.length,
                        itemBuilder: (context, index) {
                          final ware = warenSearchResults.value[index];
                          final preis = ware.bruttopreis;
                          return ListTile(
                            dense: true,
                            title: Text(ware.bezeichnung),
                            trailing: Text(currencyFormatter.format(preis)),
                            onTap: () => addPosition(ware),
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () => showWarenSearch.value = false,
                      child: const Text('Schließen'),
                    ),
                  ],
                ),
              ),

            if (positionen.value.isNotEmpty) ...[
              const Gap(16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Bezeichnung',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Menge',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Preis',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Gesamt',
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(width: 40),
                        ],
                      ),
                      const Divider(),
                      ...positionen.value.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pos = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(flex: 4, child: Text(pos.bezeichnung)),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 16,
                                        ),
                                        onPressed: () =>
                                            decreaseQuantity(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 48,
                                      alignment: Alignment.center,
                                      child: Text(
                                        pos.menge.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        onPressed: () =>
                                            increaseQuantity(index),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currencyFormatter.format(
                                    pos.einzelpreisBrutto,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currencyFormatter.format(pos.gesamtBrutto),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => removePosition(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      _buildSummaryRow(
                        'Netto:',
                        currencyFormatter.format(gesamtNetto),
                      ),
                      _buildSummaryRow(
                        'MwSt:',
                        currencyFormatter.format(gesamtMwst),
                      ),
                      _buildSummaryRow(
                        'Brutto:',
                        currencyFormatter.format(gesamtBrutto),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      onSave: saveRechnung,
      isSaving: isSaving.value,
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Gap(16),
          SizedBox(
            width: 120,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
