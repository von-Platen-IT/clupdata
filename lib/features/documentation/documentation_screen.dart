import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Screen zur Anzeige der Benutzerdokumentation mit Navigation und Suchfunktion.
class DocumentationScreen extends HookConsumerWidget {
  const DocumentationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final selectedDoc = useState<String?>(null);
    final searchResults = useState<List<_DocEntry>>([]);
    final isSearching = useState(false);

    final allDocs = useMemoized(() => _loadDocumentation());

    void performSearch(String query) {
      if (query.isEmpty) {
        searchResults.value = [];
        isSearching.value = false;
        return;
      }
      isSearching.value = true;
      final results = allDocs.where((doc) {
        return doc.title.toLowerCase().contains(query.toLowerCase());
      }).toList();
      searchResults.value = results;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hilfe & Dokumentation'),
        actions: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Suche...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: performSearch,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left sidebar: Navigation
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    'Inhaltsverzeichnis',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      if (isSearching.value && searchResults.value.isNotEmpty)
                        _buildSearchResultsSection(
                          context,
                          searchResults.value,
                          selectedDoc,
                        )
                      else ...[
                        _buildNavSection(context, 'Hauptfunktionen', [
                          _DocEntry('Start', '01_start.md', Icons.home),
                          _DocEntry(
                            'Mitglieder',
                            '02_mitglieder.md',
                            Icons.people,
                          ),
                          _DocEntry(
                            'Leistungen',
                            '03_leistungen.md',
                            Icons.description,
                          ),
                          _DocEntry(
                            'Beiträge',
                            '04_beitraege.md',
                            Icons.payments,
                          ),
                          _DocEntry('Waren', '05_waren.md', Icons.inventory),
                          _DocEntry(
                            'Rechnungen',
                            '06_rechnungen.md',
                            Icons.receipt,
                          ),
                          _DocEntry(
                            'Kursplan',
                            '07_kursplan.md',
                            Icons.calendar_today,
                          ),
                        ], selectedDoc),
                        const Divider(),
                        _buildNavSection(context, 'Menüleisten-Funktionen', [
                          _DocEntry('Datei-Menü', '10_datei.md', Icons.folder),
                          _DocEntry(
                            'Erstellen-Menü',
                            '11_erstellen.md',
                            Icons.add_circle,
                          ),
                          _DocEntry(
                            'Datenübertragung',
                            '12_datenuebertragung.md',
                            Icons.sync,
                          ),
                          _DocEntry('Hilfe-Menü', '13_hilfe.md', Icons.help),
                        ], selectedDoc),
                        const Divider(),
                        _buildNavSection(context, 'Weitere Themen', [
                          _DocEntry(
                            'Status-Farben',
                            '20_status_farben.md',
                            Icons.palette,
                          ),
                          _DocEntry(
                            'Bemerkungen',
                            '21_bemerkungen.md',
                            Icons.note,
                          ),
                          _DocEntry(
                            'Tastenkürzel',
                            '22_tastenkuerzel.md',
                            Icons.keyboard,
                          ),
                        ], selectedDoc),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Right content: Documentation display
          Expanded(
            child: selectedDoc.value != null
                ? _DocumentationContent(
                    fileName: selectedDoc.value!,
                    onBack: () => selectedDoc.value = null,
                  )
                : _buildWelcomeScreen(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Willkommen in der Hilfe & Dokumentation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Wählen Sie ein Thema aus dem Inhaltsverzeichnis\noder verwenden Sie die Suchfunktion.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavSection(
    BuildContext context,
    String title,
    List<_DocEntry> entries,
    ValueNotifier<String?> selectedDoc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...entries.map(
          (entry) => _DocNavItem(
            entry: entry,
            isSelected: selectedDoc.value == entry.fileName,
            onTap: () => selectedDoc.value = entry.fileName,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsSection(
    BuildContext context,
    List<_DocEntry> results,
    ValueNotifier<String?> selectedDoc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Suchergebnisse (${results.length})',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...results.map(
          (entry) => _DocNavItem(
            entry: entry,
            isSelected: selectedDoc.value == entry.fileName,
            onTap: () => selectedDoc.value = entry.fileName,
          ),
        ),
      ],
    );
  }
}

class _DocNavItem extends StatelessWidget {
  final _DocEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _DocNavItem({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(entry.icon, size: 20),
      title: Text(entry.title),
      selected: isSelected,
      dense: true,
      onTap: onTap,
    );
  }
}

class _DocumentationContent extends HookConsumerWidget {
  final String fileName;
  final VoidCallback onBack;

  const _DocumentationContent({required this.fileName, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = useState<String?>(null);
    final isLoading = useState(true);

    useEffect(() {
      _loadContent(context, content, isLoading);
      return null;
    }, [fileName]);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Zurück zur Übersicht',
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Text(
                fileName.replaceAll('.md', '').replaceAll(RegExp(r'^\d+_'), ''),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _MarkdownRenderer(content: content.value ?? ''),
                ),
        ),
      ],
    );
  }

  Future<void> _loadContent(
    BuildContext context,
    ValueNotifier<String?> content,
    ValueNotifier<bool> isLoading,
  ) async {
    isLoading.value = true;
    try {
      final assetContent = await rootBundle.loadString(
        'lib/assets/docs/$fileName',
      );
      content.value = assetContent;
    } catch (e) {
      content.value = '# Fehler\n\nDokument konnte nicht geladen werden.';
    }
    isLoading.value = false;
  }
}

/// Simple Markdown renderer for basic documentation content.
class _MarkdownRenderer extends StatelessWidget {
  final String content;

  const _MarkdownRenderer({required this.content});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.substring(2),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              line.substring(3),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              line.substring(4),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else if (line.startsWith('|') && !line.contains('---')) {
        final cells = line
            .split('|')
            .where((c) => c.trim().isNotEmpty)
            .map((c) => c.trim())
            .toList();
        if (cells.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: cells
                    .map(
                      (cell) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            cell,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: _InlineMarkdown(
                    text: line.substring(2),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('---')) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: _InlineMarkdown(
              text: line,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// Renders inline markdown elements like **bold** and `code`.
class _InlineMarkdown extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _InlineMarkdown({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    final matches = regex.allMatches(text);

    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: (style ?? const TextStyle()).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: 'monospace',
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

class _DocEntry {
  final String title;
  final String fileName;
  final IconData icon;

  _DocEntry(this.title, this.fileName, this.icon);
}

List<_DocEntry> _loadDocumentation() {
  return [
    _DocEntry('Start', '01_start.md', Icons.home),
    _DocEntry('Mitglieder', '02_mitglieder.md', Icons.people),
    _DocEntry('Leistungen', '03_leistungen.md', Icons.description),
    _DocEntry('Beiträge', '04_beitraege.md', Icons.payments),
    _DocEntry('Waren', '05_waren.md', Icons.inventory),
    _DocEntry('Rechnungen', '06_rechnungen.md', Icons.receipt),
    _DocEntry('Kursplan', '07_kursplan.md', Icons.calendar_today),
    _DocEntry('Datei-Menü', '10_datei.md', Icons.folder),
    _DocEntry('Erstellen-Menü', '11_erstellen.md', Icons.add_circle),
    _DocEntry('Datenübertragung', '12_datenuebertragung.md', Icons.sync),
    _DocEntry('Hilfe-Menü', '13_hilfe.md', Icons.help),
    _DocEntry('Status-Farben', '20_status_farben.md', Icons.palette),
    _DocEntry('Bemerkungen', '21_bemerkungen.md', Icons.note),
    _DocEntry('Tastenkürzel', '22_tastenkuerzel.md', Icons.keyboard),
  ];
}
