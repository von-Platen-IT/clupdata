# Beiträge Refactoring - Implementierungsdetails

## Übersicht der zu erstellenden/ändernden Dateien

### Neue Dateien (7)
1. `lib/features/beitraege/domain/models/beitrag_status.dart` - Enum mit Extensions
2. `lib/features/beitraege/presentation/widgets/status_badge.dart` - Wiederverwendbares Status-Badge
3. `lib/features/beitraege/presentation/widgets/status_history_list.dart` - Status-Historie Widget
4. `lib/common_widgets/forms/app_entity_autocomplete.dart` - Generisches Autocomplete
5. `lib/features/beitraege/domain/providers/single_beitrag_provider.dart` - Einzel-Item Provider
6. `lib/features/beitraege/presentation/dialogs/sections/member_selection_section.dart` - Mitglied-Auswahl
7. `lib/features/beitraege/presentation/dialogs/sections/leistung_selection_section.dart` - Leistung-Auswahl

### Zu ändernde Dateien (5)
1. `lib/features/beitraege/utils/beitrag_status_colors.dart` - Wird ersetzt durch Enum
2. `lib/features/beitraege/providers/beitraege_repository.dart` - Optimierungen
3. `lib/features/beitraege/presentation/widgets/beitrag_data_grid.dart` - Neue Widgets nutzen
4. `lib/features/beitraege/presentation/dialogs/beitrag_edit_dialog.dart` - Refactoring
5. `lib/features/beitraege/presentation/dialogs/neuer_beitrag_dialog.dart` - Refactoring

---

## Phase 1: Domain Layer - BeitragStatus Enum

### Datei: lib/features/beitraege/domain/models/beitrag_status.dart (NEU)

```dart
import 'package:flutter/material.dart';

/// Enum representing all possible states of a Beitrag (contribution/invoice).
/// Replaces the string-based status handling with type-safe operations.
enum BeitragStatus {
  kontiert,    // Newly created, not yet processed
  offen,       // Invoice sent, awaiting payment
  bezahlt,     // Fully paid
  angemahnt,   // Reminder sent
  storniert,   // Cancelled
  inkasso;     // Handed to collections agency

  /// Returns the database string representation.
  String get value => name;

  /// Creates a BeitragStatus from a database string.
  static BeitragStatus fromString(String value) {
    return BeitragStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BeitragStatus.kontiert,
    );
  }

  /// Human-readable label for the status.
  String get label {
    switch (this) {
      case BeitragStatus.kontiert:
        return 'Kontiert';
      case BeitragStatus.offen:
        return 'Offen';
      case BeitragStatus.bezahlt:
        return 'Bezahlt';
      case BeitragStatus.angemahnt:
        return 'Angemahnt';
      case BeitragStatus.storniert:
        return 'Storniert';
      case BeitragStatus.inkasso:
        return 'Inkasso';
    }
  }

  /// Background color for status badges and row highlighting.
  Color get backgroundColor {
    switch (this) {
      case BeitragStatus.kontiert:
        return const Color(0xFFFFF9C4); // light yellow
      case BeitragStatus.offen:
        return const Color(0xFFFFE0B2); // light orange
      case BeitragStatus.bezahlt:
        return const Color(0xFFC8E6C9); // light green
      case BeitragStatus.angemahnt:
        return const Color(0xFFFFCDD2); // light red
      case BeitragStatus.storniert:
        return const Color(0xFFEEEEEE); // light grey
      case BeitragStatus.inkasso:
        return const Color(0xFFF8BBD0); // pink
    }
  }

  /// Foreground/text color (always dark for pastel backgrounds).
  Color get textColor => Colors.black87;

  /// Whether this status allows editing of the Beitrag.
  bool get isEditable => this != BeitragStatus.bezahlt && this != BeitragStatus.storniert;

  /// Whether this status indicates the invoice is still open/unpaid.
  bool get isOpen => this == BeitragStatus.offen || this == BeitragStatus.angemahnt;

  /// Whether this status indicates the invoice is finalized.
  bool get isFinal => this == BeitragStatus.bezahlt || this == BeitragStatus.storniert;

  /// All status values for dropdowns.
  static List<BeitragStatus> get allValues => BeitragStatus.values;

  /// All status values as strings for legacy compatibility.
  static List<String> get allStringValues => 
      BeitragStatus.values.map((s) => s.value).toList();
}

/// Extension on String for easy conversion.
extension BeitragStatusStringExtension on String {
  BeitragStatus toBeitragStatus() => BeitragStatus.fromString(this);
}

/// Extension on Color for alpha adjustments.
extension ColorAlphaExtension on Color {
  Color withOpacityPercent(double percent) {
    return withAlpha((255 * percent).round());
  }
}
```

---

## Phase 2: Widget Extractions

### Datei: lib/features/beitraege/presentation/widgets/status_badge.dart (NEU)

```dart
import 'package:flutter/material.dart';
import '../../domain/models/beitrag_status.dart';

/// A reusable badge widget for displaying BeitragStatus.
/// Used in DataGrids, Dialogs, and Status History.
class StatusBadge extends StatelessWidget {
  final BeitragStatus status;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool showBorder;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    this.showBorder = true,
  });

  /// Factory constructor for creating from string value.
  factory StatusBadge.fromString(
    String statusValue, {
    double fontSize = 12,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    bool showBorder = true,
  }) {
    return StatusBadge(
      status: BeitragStatus.fromString(statusValue),
      fontSize: fontSize,
      padding: padding,
      showBorder: showBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: status.backgroundColor,
        border: showBorder
            ? Border.all(color: status.backgroundColor.withOpacityPercent(0.5))
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: fontSize,
          color: status.textColor,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
```

### Datei: lib/features/beitraege/presentation/widgets/status_history_list.dart (NEU)

```dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database.dart';
import '../../domain/models/beitrag_status.dart';
import 'status_badge.dart';

/// Displays a scrollable list of status history entries.
/// Used in BeitragEditDialog and potentially other places.
class StatusHistoryList extends StatelessWidget {
  final List<BeitragStatusVerlaufData> history;
  final DateFormat? dateFormatter;
  final double maxHeight;

  const StatusHistoryList({
    super.key,
    required this.history,
    this.dateFormatter,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = dateFormatter ?? DateFormat('dd.MM.yyyy');

    if (history.isEmpty) {
      return const Text('Keine Status-Historie vorhanden.');
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          final status = BeitragStatus.fromString(entry.status);
          final isLast = index == history.length - 1;

          return _HistoryEntryTile(
            entry: entry,
            status: status,
            dateFormatter: formatter,
            isLast: isLast,
          );
        },
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final BeitragStatusVerlaufData entry;
  final BeitragStatus status;
  final DateFormat dateFormatter;
  final bool isLast;

  const _HistoryEntryTile({
    required this.entry,
    required this.status,
    required this.dateFormatter,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: status.backgroundColor.withOpacityPercent(0.3),
        border: Border(
          bottom: !isLast
              ? BorderSide(color: Colors.grey.shade200)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          StatusBadge(
            status: status,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.bemerkung,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(2),
                Text(
                  dateFormatter.format(entry.geaendertAm),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 3: Generisches Autocomplete-Widget

### Datei: lib/common_widgets/forms/app_entity_autocomplete.dart (NEU)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A generic, reusable autocomplete widget for entity selection.
/// Eliminates code duplication between member and leistung selection.
/// 
/// Type parameter [T] represents the entity type (e.g., Mitglied, Leistung).
class AppEntityAutocomplete<T> extends HookWidget {
  final TextEditingController controller;
  final ValueNotifier<T?> selectedEntity;
  final String label;
  final String hintText;
  final String Function(T) displayStringForOption;
  final Widget Function(T) subtitleBuilder;
  final Future<List<T>> Function(String) onSearch;
  final Future<List<T>> Function() onLoadAll;
  final double optionsWidth;
  final double optionsMaxHeight;

  const AppEntityAutocomplete({
    super.key,
    required this.controller,
    required this.selectedEntity,
    required this.label,
    required this.hintText,
    required this.displayStringForOption,
    required this.subtitleBuilder,
    required this.onSearch,
    required this.onLoadAll,
    this.optionsWidth = 400,
    this.optionsMaxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    final searchResults = useState<List<T>>([]);

    Future<void> handleSearch(String query) async {
      if (query.length < 2) {
        searchResults.value = [];
        return;
      }
      final results = await onSearch(query);
      searchResults.value = results;
    }

    Future<void> handleLoadAll() async {
      final results = await onLoadAll();
      searchResults.value = results;
    }

    return Autocomplete<T>(
      optionsBuilder: (textEditingValue) {
        // Show all results when text is exactly ' ' (triggered by search button)
        if (textEditingValue.text == ' ') {
          return searchResults.value;
        }
        if (textEditingValue.text.length < 2) {
          return const Iterable<T>.empty();
        }
        // Trigger search and return current results
        handleSearch(textEditingValue.text);
        return searchResults.value;
      },
      displayStringForOption: displayStringForOption,
      onSelected: (entity) {
        selectedEntity.value = entity;
        controller.text = displayStringForOption(entity);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sync external controller with internal one
        if (controller.text != textEditingController.text) {
          textEditingController.text = controller.text;
        }

        return Stack(
          alignment: Alignment.centerRight,
          children: [
            TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: selectedEntity.value != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          selectedEntity.value = null;
                          controller.clear();
                          textEditingController.clear();
                        },
                      )
                    : const SizedBox(width: 40, height: 40),
              ),
              onChanged: (value) {
                controller.text = value;
                if (selectedEntity.value != null) {
                  selectedEntity.value = null;
                }
              },
            ),
            if (selectedEntity.value == null)
              Positioned(
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) async {
                    await handleLoadAll();
                  },
                  onTapUp: (_) {
                    textEditingController.text = ' ';
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(Icons.search, size: 20),
                  ),
                ),
              ),
          ],
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: Container(
              width: optionsWidth,
              constraints: BoxConstraints(maxHeight: optionsMaxHeight),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final entity = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(displayStringForOption(entity)),
                    subtitle: subtitleBuilder(entity),
                    onTap: () => onSelected(entity),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Phase 4: Repository-Optimierungen

### Änderungen in: lib/features/beitraege/providers/beitraege_repository.dart

#### 4.1 Neue Single-Item Provider hinzufügen:

```dart
/// Provider for watching a single Beitrag by ID.
/// More efficient than watching the entire list.
@riverpod
Stream<BeitragRowData?> singleBeitrag(Ref ref, int beitragId) {
  return ref
      .watch(beitraegeRepositoryProvider)
      .watchSingleBeitrag(beitragId);
}
```

#### 4.2 Neue Repository-Methode:

```dart
/// Streams a single BeitragRowData by ID.
/// More efficient than loading the entire list.
Stream<BeitragRowData?> watchSingleBeitrag(int beitragId) {
  final query = _db.select(_db.beitraege).join([
    innerJoin(
      _db.mitglieds,
      _db.mitglieds.id.equalsExp(_db.beitraege.mitgliedId),
    ),
    innerJoin(
      _db.leistung,
      _db.leistung.id.equalsExp(_db.beitraege.leistungId),
    ),
  ])
    ..where(_db.beitraege.id.equals(beitragId));

  return query.watchSingleOrNull().map((row) {
    if (row == null) return null;
    final beitrag = row.readTable(_db.beitraege);
    final mitglied = row.readTable(_db.mitglieds);
    final leistung = row.readTable(_db.leistung);
    return BeitragRowData(
      beitrag: beitrag,
      mitgliedName: '${mitglied.name}, ${mitglied.vorname}',
      leistungName: leistung.name,
    );
  });
}
```

#### 4.3 Bemerkung-Utility extrahieren:

```dart
/// Mixin providing common Bemerkung (note) operations.
/// Can be reused across different repositories.
mixin BemerkungRepositoryMixin on RepositoryBase {
  Future<int> saveBemerkung(int? existingId, String titel, String text) async {
    if (existingId != null) {
      await (db.update(db.bemerkung)
            ..where((b) => b.id.equals(existingId)))
          .write(
            BemerkungCompanion(
              titel: Value(titel),
              textValue: Value(text),
            ),
          );
      return existingId;
    } else {
      return db.into(db.bemerkung).insert(
            BemerkungCompanion.insert(
              titel: titel,
              textValue: Value(text),
            ),
          );
    }
  }
}

/// Base class for repositories.
abstract class RepositoryBase {
  AppDatabase get db;
}
```

---

## Phase 5: Dialog-Refactoring

### Datei: lib/features/beitraege/presentation/dialogs/sections/member_selection_section.dart (NEU)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../../common_widgets/app_section_header.dart';
import '../../../../../common_widgets/forms/app_entity_autocomplete.dart';
import '../../../../../core/database/database.dart';
import '../../../../members/data/members_repository.dart';

/// Section for selecting a member in the new Beitrag dialog.
class MemberSelectionSection extends HookConsumerWidget {
  final ValueNotifier<Mitglied?> selectedMember;

  const MemberSelectionSection({
    super.key,
    required this.selectedMember,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final repo = ref.read(membersRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader('Mitglied'),
        const Gap(8),
        AppEntityAutocomplete<Mitglied>(
          controller: searchController,
          selectedEntity: selectedMember,
          label: 'Mitglied suchen (Vor- oder Nachname)',
          hintText: 'Mindestens 2 Zeichen eingeben...',
          displayStringForOption: (m) => '${m.vorname} ${m.name}',
          subtitleBuilder: (m) => Text('${m.plz ?? ''} ${m.ort ?? ''}'),
          onSearch: (query) => repo.searchMembers(query),
          onLoadAll: () => repo.getAllMembers(),
        ),
        if (selectedMember.value != null) ...[
          const Gap(8),
          _SelectedMemberCard(member: selectedMember.value!),
        ],
      ],
    );
  }
}

class _SelectedMemberCard extends StatelessWidget {
  final Mitglied member;

  const _SelectedMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.blue.shade700),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${member.vorname} ${member.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (member.ort != null && member.ort!.isNotEmpty)
                  Text(
                    '${member.plz ?? ''} ${member.ort}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### Ähnlich für LeistungSelectionSection...

---

## Phase 6: Migration bestehender Dateien

### Schritte für beitrag_data_grid.dart:

1. Import entfernen: `import '../../utils/beitrag_status_colors.dart';`
2. Import hinzufügen: `import '../../domain/models/beitrag_status.dart';` und `import 'status_badge.dart';`
3. Renderer ersetzen:

```dart
// Alt:
renderer: (rendererContext) {
  final status = rendererContext.cell.value as String? ?? '';
  final color = beitragStatusColor(status);
  return Container(...);
}

// Neu:
renderer: (rendererContext) {
  final statusValue = rendererContext.cell.value as String? ?? '';
  return StatusBadge.fromString(statusValue);
}
```

### Schritte für beitrag_edit_dialog.dart:

1. Status-Historie-Logik entfernen und durch `StatusHistoryList` Widget ersetzen
2. Status-Dropdown durch Enum-basierte Version ersetzen
3. Single-Item Provider verwenden statt gesamte Liste

---

## Checkliste für Implementierung

- [ ] BeitragStatus Enum erstellt
- [ ] StatusBadge Widget erstellt
- [ ] StatusHistoryList Widget erstellt
- [ ] AppEntityAutocomplete Widget erstellt
- [ ] Single-Beitrag Provider hinzugefügt
- [ ] Bemerkung Mixin erstellt
- [ ] beitrag_data_grid.dart migriert
- [ ] beitrag_edit_dialog.dart refactored
- [ ] neuer_beitrag_dialog.dart refactored
- [ ] Alte beitrag_status_colors.dart entfernt
- [ ] Tests durchgeführt
