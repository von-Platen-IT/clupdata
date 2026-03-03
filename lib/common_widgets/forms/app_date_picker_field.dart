import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

/// A reusable standard date picker field optimized for desktop usage and keyboard traversal.
class AppDatePickerField extends HookWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final bool required;
  final FocusNode? focusNode;

  const AppDatePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.required = false,
    this.focusNode,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: label,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy');
    final controller = useTextEditingController(text: value != null ? formatter.format(value!) : '');
    final focus = focusNode ?? useFocusNode();

    // Re-sync text if external value changes while we are not focused
    useEffect(() {
      if (!focus.hasFocus) {
        final expectedText = value != null ? formatter.format(value!) : '';
        if (controller.text != expectedText) {
          controller.text = expectedText;
        }
      }
      return null;
    }, [value, focus.hasFocus]);

    // Parse the typed text when focus is lost
    useEffect(() {
      void listener() {
        if (!focus.hasFocus) {
           final text = controller.text.trim();
           if (text.isEmpty) {
              if (value != null) onChanged(null);
           } else {
              try {
                final parts = text.split('.');
                if (parts.length >= 2) {
                   int day = int.tryParse(parts[0]) ?? 1;
                   int month = int.tryParse(parts[1]) ?? 1;
                   int year = parts.length == 3 ? (int.tryParse(parts[2]) ?? DateTime.now().year) : DateTime.now().year;
                   if (year < 100) year += 2000;
                   
                   final parsed = DateTime(year, month, day);
                   // Avoid unnecessary updates if the date hasn't changed
                   if (value == null || (value!.day != parsed.day || value!.month != parsed.month || value!.year != parsed.year)) {
                      onChanged(parsed);
                   }
                } else {
                   // Fallback logic for wrong format: just revert to original
                   controller.text = value != null ? formatter.format(value!) : '';
                }
              } catch (e) {
                 controller.text = value != null ? formatter.format(value!) : '';
              }
           }
        }
      }
      
      focus.addListener(listener);
      return () => focus.removeListener(listener);
    }, [focus, value]);

    return TextField(
      controller: controller,
      focusNode: focus,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _pickDate(context),
          tooltip: 'Datum wählen',
          focusNode: FocusNode(skipTraversal: true), // Skip the icon in Tab sequence
        ),
      ),
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => focus.nextFocus(), // Allow enter to move to next field
    );
  }
}
