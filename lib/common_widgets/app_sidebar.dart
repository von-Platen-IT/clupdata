import 'package:flutter/material.dart';

/// Ein Eintrag der Seitenleiste.
class AppSidebarItem {
  const AppSidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Seitenleiste der Anwendung mit deutlich sichtbarer Aktiv-Markierung.
///
/// Die Auswahl ist bewusst kräftig gestaltet (primärer Hintergrund +
/// linker Akzentbalken + fetter Text + gefülltes Icon), damit der aktive
/// Punkt sofort erkennbar ist – nicht nur über einen farblichen Indicator.
///
/// Wird eine Aktion im Hauptmenü gewählt ([istMenuAktiv] = true), wird die
/// Auswahl im Seitenmenü ausgeblendet, damit kein doppelter aktiver Zustand
/// entsteht.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.leading,
    required this.trailing,
    this.extended = true,
    this.istMenuAktiv = false,
  });

  final List<AppSidebarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final Widget leading;
  final Widget trailing;
  final bool extended;

  /// True, wenn eine Aktion im Hauptmenü aktiv ist – dann wird kein
  /// Sidebar-Eintrag als ausgewählt markiert.
  final bool istMenuAktiv;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 200 : 72,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          leading,
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, index) => _SidebarTile(
                item: items[index],
                ausgewaehlt: !istMenuAktiv && index == selectedIndex,
                extended: extended,
                onTap: () => onItemSelected(index),
              ),
            ),
          ),
          trailing,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Ein einzelner Sidebar-Eintrag mit kräftiger Aktiv-Markierung.
class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.ausgewaehlt,
    required this.extended,
    required this.onTap,
  });

  final AppSidebarItem item;
  final bool ausgewaehlt;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = ausgewaehlt
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final hintergrund = ausgewaehlt
        ? theme.colorScheme.primaryContainer
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: hintergrund,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              // Linker Akzentbalken bei aktiver Auswahl.
              border: Border(
                left: BorderSide(
                  color: ausgewaehlt
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 4,
                ),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: extended
                ? Row(
                    children: [
                      Icon(
                        ausgewaehlt ? item.selectedIcon : item.icon,
                        color: farbe,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: farbe,
                            fontWeight: ausgewaehlt
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(
                        ausgewaehlt ? item.selectedIcon : item.icon,
                        color: farbe,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: farbe,
                          fontWeight: ausgewaehlt
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
