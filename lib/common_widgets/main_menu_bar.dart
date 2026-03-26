import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/providers/active_data_grid_provider.dart';
import 'package:printing/printing.dart';
import '../features/members/widgets/member_edit_dialog.dart';
import '../features/leistungen/widgets/leistung_edit_dialog.dart';
import '../features/waren/widgets/waren_edit_dialog.dart';
import '../features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart';
import '../widgets/data_grid_v2/export/csv_exporter.dart';
import '../widgets/data_grid_v2/export/pdf/pdf_exporter.dart';
import '../widgets/data_grid_v2/export/pdf/pdf_preview_dialog.dart';
import '../widgets/data_grid_v2/export/pdf/pdf_template_registry.dart';

class MainMenuBar extends ConsumerWidget {
  const MainMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hier verwenden wir eine einfache AppBar als MenuBar-Ersatz,
    // um die Kompatibilität auf allen OS zu garantieren und es einheitlich zu stylen.
    return Container(
      height: 36, // Klassische Desktop-Menühöhe
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _MenuButton(
            title: 'Datei',
            items: [
              PopupMenuItem(child: const Text('Einstellungen'), onTap: () {}),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Beenden'),
                onTap: () {
                  exit(0);
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Erstellen',
            items: [
              PopupMenuItem(
                child: const Text('Mitglied'),
                onTap: () {
                  // Dialog zum Hinzufügen eines Mitglieds öffnen
                  MemberEditDialog.show(context);
                },
              ),
              PopupMenuItem(
                child: const Text('Leistung'),
                onTap: () {
                  // Dialog zum Hinzufügen einer Leistung öffnen
                  LeistungEditDialog.show(context);
                },
              ),
              PopupMenuItem(
                child: const Text('Ware'),
                onTap: () {
                  // Dialog zum Hinzufügen einer Ware öffnen
                  WarenEditDialog.show(context);
                },
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Rechnungslegung'),
                onTap: () {
                  // Dialog zur Massenerstellung von Beiträgen öffnen
                  RechnungslegungDialog.show(context);
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Exportieren',
            items: [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.print_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Drucken...'),
                  ],
                ),
                onTap: () async {
                  final controller = ref.read(activeDataGridControllerProvider);
                  if (controller == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Keine Tabelle aktiv. Bitte wähle zuerst eine Funktion im Seitenmenü.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  // Show loading dialog
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 20),
                            Text('Druckdaten werden aufbereitet...'),
                          ],
                        ),
                      ),
                    );
                  }

                  try {
                    final exporter = PdfExporter(
                      template: PdfTemplateRegistry.simple,
                    );
                    final pdfBytes = await exporter.exportList(
                      controller,
                      title: 'Druck',
                    );

                    // Hide loading
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }

                    // Native Print
                    await Printing.layoutPdf(
                      onLayout: (format) async => pdfBytes,
                      name: 'ClupData Export',
                    );
                  } catch (e) {
                    // Hide loading
                    if (context.mounted && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim Drucken: $e')),
                      );
                    }
                  }
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('PDF erstellen'),
                  ],
                ),
                onTap: () async {
                  final controller = ref.read(activeDataGridControllerProvider);
                  if (controller == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Keine Tabelle aktiv. Bitte wähle zuerst eine Funktion im Seitenmenü.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  // Show loading dialog
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 20),
                            Text('PDF wird erstellt...'),
                          ],
                        ),
                      ),
                    );
                  }

                  try {
                    final exporter = PdfExporter(
                      template: PdfTemplateRegistry.simple,
                    );
                    final pdfBytes = await exporter.exportList(
                      controller,
                      title: 'Export',
                    );

                    // Hide loading
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }

                    // Show preview
                    if (context.mounted) {
                      await showDialog(
                        context: context,
                        builder: (_) => PdfPreviewDialog(
                          pdfData: pdfBytes,
                          title: 'PDF Export',
                        ),
                      );
                    }
                  } catch (e) {
                    // Hide loading
                    if (context.mounted && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim PDF-Export: $e')),
                      );
                    }
                  }
                },
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('CSV erstellen'),
                  ],
                ),
                onTap: () async {
                  final controller = ref.read(activeDataGridControllerProvider);
                  if (controller == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Keine Tabelle aktiv. Bitte wähle zuerst eine Funktion im Seitenmenü.',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  try {
                    final table = controller.toExportDataTable(title: 'export');
                    final exporter = CsvExporter();
                    final file = await exporter.export(table);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('CSV erstellt: ${file.path}'),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler beim CSV-Export: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Hilfe',
            items: [
              PopupMenuItem(
                child: const Text('Über die App'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'ClupData',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final List<PopupMenuEntry<dynamic>> items;

  const _MenuButton({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.black12,
      ),
      child: PopupMenuButton(
        offset: const Offset(0, 30),
        tooltip: '',
        itemBuilder: (context) => items,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
