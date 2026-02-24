import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart' show StateProvider;
import '../../core/database/database.dart';
import 'data/schedule_repository.dart';

// --- Constants ---

/// Weekday labels Mon–Sun, index 0 = Monday (weekday value 1).
const _weekdayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// First displayed hour of the day.
const _startHour = 0;

/// Last displayed hour (exclusive).
const _endHour = 24;

/// Height of each 30-min time slot row, in logical pixels.
const _rowHeight = 44.0;

/// Minimum width of a weekday column, in logical pixels.
const _minDayColWidth = 110.0;

/// Width of the time-label column on the left.
const _timeColWidth = 52.0;

/// Color palette per weekday (Mon–Sun).
const _weekdayColors = [
  Color(0xFF1E88E5), // Mon – blue
  Color(0xFF43A047), // Tue – green
  Color(0xFFE53935), // Wed – red
  Color(0xFFFB8C00), // Thu – orange
  Color(0xFF8E24AA), // Fri – purple
  Color(0xFF00ACC1), // Sat – cyan
  Color(0xFF6D4C41), // Sun – brown
];

/// Holds the ID of the currently selected course (`null` = nothing selected).
final selectedCourseIdProvider = StateProvider<int?>((ref) => null);

// ---------------------------------------------------------------------------
// Main Screen
// ---------------------------------------------------------------------------

/// The weekly course-schedule calendar screen.
///
/// Shows a scrollable timetable for the full 0–24h day. Columns represent
/// weekdays (Mon–Sun), rows represent 30-min slots.
/// Users select a course card to enable the "Kurs bearbeiten" toolbar button.
class CalendarScreen extends ConsumerWidget {
  /// Creates the calendar screen.
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(scheduleStreamProvider);
    final selectedId = ref.watch(selectedCourseIdProvider);

    final CourseSchedule? selectedCourse = schedulesAsync.when(
      data: (list) => list.where((c) => c.id == selectedId).firstOrNull,
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kursplan'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              ref.read(selectedCourseIdProvider.notifier).state = null;
              showDialog(context: context, builder: (_) => const _AddCourseDialog());
            },
            icon: const Icon(Icons.add),
            label: const Text('Kurs hinzufügen'),
          ),
          const Gap(8),
          FilledButton.tonalIcon(
            onPressed: selectedCourse == null
                ? null
                : () => showDialog(
                      context: context,
                      builder: (_) => _EditCourseDialog(course: selectedCourse),
                    ),
            icon: const Icon(Icons.edit),
            label: const Text('Kurs bearbeiten'),
          ),
          const Gap(16),
        ],
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (schedules) => _Timetable(schedules: schedules),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timetable – 2D scrollable, pinned weekday header
// ---------------------------------------------------------------------------

/// A 2-axis scrollable weekly timetable.
///
/// The weekday header row is pinned at the top. The time-label column is part
/// of the horizontal scroll so it moves with the content. Vertical scroll
/// covers the full 0–24h day (48 × 30-min slots at [_rowHeight] each).
class _Timetable extends HookWidget {
  final List<CourseSchedule> schedules;

  const _Timetable({required this.schedules});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const headerHeight = 36.0;

    // Single controller per axis – no shared-controller problem because
    // the horizontal scroll now wraps BOTH the header and the body together.
    final hCtrl = useScrollController();
    final vCtrl = useScrollController();

    return LayoutBuilder(builder: (context, constraints) {
      // Day column: at least minWidth, expands to fill available space.
      final dayColWidth = ((constraints.maxWidth - _timeColWidth) / 7)
          .clamp(_minDayColWidth, double.infinity);
      final tableWidth = _timeColWidth + dayColWidth * 7;

      // Height available for the vertical-scroll body.
      final bodyHeight = constraints.maxHeight - headerHeight - 1 /* divider */;

      // ── Outer: horizontal scroll (puts H-scrollbar at viewport bottom) ──
      return Scrollbar(
        controller: hCtrl,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: hCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                // ── Pinned header (inside h-scroll, above v-scroll) ────────
                SizedBox(
                  height: headerHeight,
                  child: Row(
                    children: [
                      SizedBox(width: _timeColWidth),
                      ...List.generate(7, (i) => SizedBox(
                        width: dayColWidth,
                        child: Container(
                          alignment: Alignment.center,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Text(
                            _weekdayLabels[i],
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Inner: vertical scroll ──────────────────────────────────
                SizedBox(
                  height: bodyHeight,
                  child: Scrollbar(
                    controller: vCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: vCtrl,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time labels column
                          SizedBox(
                            width: _timeColWidth,
                            child: Column(
                              children: [
                                for (int h = _startHour; h < _endHour; h++)
                                  for (int half = 0; half < 2; half++)
                                    SizedBox(
                                      height: _rowHeight,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 3),
                                          child: Text(
                                            half == 0
                                                ? '${h.toString().padLeft(2, '0')}:00'
                                                : '',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.outline,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          // Day columns
                          ...List.generate(7, (dayIdx) {
                            final weekdayValue = dayIdx + 1;
                            return SizedBox(
                              width: dayColWidth,
                              child: Column(
                                children: [
                                  for (int h = _startHour; h < _endHour; h++)
                                    for (int half = 0; half < 2; half++)
                                      _buildCell(theme, h, half * 30, weekdayValue, dayIdx),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }


  /// Builds a single timetable cell for [weekdayValue] at [hour]:[minute].
  Widget _buildCell(ThemeData theme, int hour, int minute, int weekdayValue, int dayIdx) {
    final course = schedules.firstWhere(
      (s) => s.weekday == weekdayValue && s.startHour == hour && s.startMinute == minute,
      orElse: () => const CourseSchedule(
        id: -1, title: '', trainer: '', weekday: 0,
        startHour: 0, startMinute: 0, durationMinutes: 0, location: '',
      ),
    );
    final hasCourse = course.id != -1;

    return SizedBox(
      height: _rowHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        child: hasCourse
            ? _CourseCard(course: course, color: _weekdayColors[dayIdx])
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Course Card – tap to select / deselect
// ---------------------------------------------------------------------------

/// A coloured card for a single scheduled course.
///
/// A tap selects the card (visually highlighted); tapping again deselects.
/// Only one card can be selected at a time.
class _CourseCard extends ConsumerWidget {
  final CourseSchedule course;
  final Color color;

  const _CourseCard({required this.course, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectedCourseIdProvider);
    final isSelected = selectedId == course.id;

    return GestureDetector(
      onTap: () => ref.read(selectedCourseIdProvider.notifier).state =
          isSelected ? null : course.id,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.35) : color.withOpacity(0.15),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.6),
            width: isSelected ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 5, spreadRadius: 1)]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                course.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : color.withOpacity(0.85),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) Icon(Icons.edit_outlined, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared form builder (Add + Edit dialogs)
// ---------------------------------------------------------------------------

/// Builds the shared input form used by both [_AddCourseDialog] and [_EditCourseDialog].
Widget _buildCourseForm({
  required TextEditingController titleCtrl,
  required TextEditingController trainerCtrl,
  required TextEditingController locationCtrl,
  required ValueNotifier<int> weekday,
  required ValueNotifier<int> startHour,
  required ValueNotifier<int> startMinute,
  required ValueNotifier<int> duration,
}) {
  final weekdayNames = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
  final hourOptions = List.generate(_endHour - _startHour, (i) => _startHour + i);
  const minuteOptions = [0, 15, 30, 45];
  const durationOptions = [30, 45, 60, 75, 90, 120];

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: titleCtrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Kursname', border: OutlineInputBorder()),
      ),
      const Gap(12),
      TextField(
        controller: trainerCtrl,
        decoration: const InputDecoration(labelText: 'Trainer', border: OutlineInputBorder()),
      ),
      const Gap(12),
      TextField(
        controller: locationCtrl,
        decoration: const InputDecoration(labelText: 'Ort / Raum', border: OutlineInputBorder()),
      ),
      const Gap(12),
      DropdownButtonFormField<int>(
        decoration: const InputDecoration(labelText: 'Wochentag', border: OutlineInputBorder()),
        value: weekday.value,
        items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(weekdayNames[i]))),
        onChanged: (v) { if (v != null) weekday.value = v; },
      ),
      const Gap(12),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Stunde', border: OutlineInputBorder()),
            value: startHour.value,
            items: hourOptions.map((h) => DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))).toList(),
            onChanged: (v) { if (v != null) startHour.value = v; },
          ),
        ),
        const Gap(8),
        Expanded(
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Minute', border: OutlineInputBorder()),
            value: startMinute.value,
            items: minuteOptions.map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))).toList(),
            onChanged: (v) { if (v != null) startMinute.value = v; },
          ),
        ),
      ]),
      const Gap(12),
      DropdownButtonFormField<int>(
        decoration: const InputDecoration(labelText: 'Dauer (Minuten)', border: OutlineInputBorder()),
        value: duration.value,
        items: durationOptions.map((d) => DropdownMenuItem(value: d, child: Text('$d min'))).toList(),
        onChanged: (v) { if (v != null) duration.value = v; },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Add-Course Dialog
// ---------------------------------------------------------------------------

/// A dialog that collects all fields to create a new [CourseSchedule].
class _AddCourseDialog extends HookConsumerWidget {
  const _AddCourseDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl    = useTextEditingController();
    final trainerCtrl  = useTextEditingController();
    final locationCtrl = useTextEditingController();
    final weekday      = useState(1);
    final startHour    = useState(9);
    final startMinute  = useState(0);
    final duration     = useState(60);
    final isSaving     = useState(false);

    Future<void> save() async {
      if (titleCtrl.text.trim().isEmpty) return;
      isSaving.value = true;
      try {
        await ref.read(scheduleRepositoryProvider).addCourse(
          CourseSchedulesCompanion.insert(
            title: titleCtrl.text.trim(),
            trainer: trainerCtrl.text.trim(),
            location: Value(locationCtrl.text.trim()),
            weekday: weekday.value,
            startHour: startHour.value,
            startMinute: startMinute.value,
            durationMinutes: duration.value,
          ),
        );
        if (context.mounted) Navigator.of(context).pop();
      } finally {
        isSaving.value = false;
      }
    }

    return AlertDialog(
      title: const Text('Neuen Kurs anlegen'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: _buildCourseForm(
            titleCtrl: titleCtrl, trainerCtrl: trainerCtrl, locationCtrl: locationCtrl,
            weekday: weekday, startHour: startHour, startMinute: startMinute, duration: duration,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: isSaving.value ? null : save,
          child: isSaving.value
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Speichern'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit-Course Dialog (with Delete)
// ---------------------------------------------------------------------------

/// A dialog pre-filled with an existing [CourseSchedule].
///
/// Provides a **Löschen** button alongside the standard save action.
/// After deletion the dialog closes and the selection is cleared.
class _EditCourseDialog extends HookConsumerWidget {
  final CourseSchedule course;

  const _EditCourseDialog({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleCtrl    = useTextEditingController(text: course.title);
    final trainerCtrl  = useTextEditingController(text: course.trainer);
    final locationCtrl = useTextEditingController(text: course.location);
    final weekday      = useState(course.weekday);
    final startHour    = useState(course.startHour);
    final startMinute  = useState(course.startMinute);
    final duration     = useState(course.durationMinutes);
    final isSaving     = useState(false);

    Future<void> save() async {
      if (titleCtrl.text.trim().isEmpty) return;
      isSaving.value = true;
      try {
        await ref.read(scheduleRepositoryProvider).updateCourse(CourseSchedule(
          id: course.id,
          title: titleCtrl.text.trim(),
          trainer: trainerCtrl.text.trim(),
          location: locationCtrl.text.trim(),
          weekday: weekday.value,
          startHour: startHour.value,
          startMinute: startMinute.value,
          durationMinutes: duration.value,
        ));
        if (context.mounted) Navigator.of(context).pop();
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> delete() async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kurs löschen?'),
          content: Text('"${course.title}" wirklich entfernen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Endgültig löschen'),
            ),
          ],
        ),
      );
      if (confirm == true && context.mounted) {
        await ref.read(scheduleRepositoryProvider).deleteCourse(course.id);
        ref.read(selectedCourseIdProvider.notifier).state = null;
        if (context.mounted) Navigator.of(context).pop();
      }
    }

    return AlertDialog(
      title: const Text('Kurs bearbeiten'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: _buildCourseForm(
            titleCtrl: titleCtrl, trainerCtrl: trainerCtrl, locationCtrl: locationCtrl,
            weekday: weekday, startHour: startHour, startMinute: startMinute, duration: duration,
          ),
        ),
      ),
      // Use Row to place the delete button on the far left without Spacer inside OverflowBar.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: isSaving.value ? null : delete,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Kurs löschen', style: TextStyle(color: Colors.red)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
            const Gap(8),
            FilledButton(
              onPressed: isSaving.value ? null : save,
              child: isSaving.value
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
            ),
          ],
        ),
      ],
    );
  }
}
