import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class MasterDataDialog extends HookWidget {
  final String title;
  final String? initialValue;

  const MasterDataDialog({
    super.key,
    required this.title,
    this.initialValue,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => MasterDataDialog(
        title: title,
        initialValue: initialValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);

    return AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (value) {
          final text = value.trim();
          if (text.isNotEmpty) {
            Navigator.of(context).pop(text);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(text);
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
