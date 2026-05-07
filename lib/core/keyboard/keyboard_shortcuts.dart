import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hilfsklasse für plattformspezifische Tastatur-Shortcuts.
class AppKeyboardShortcuts {
  /// Prüft ob die App auf macOS läuft.
  static bool get isMacOS => Platform.isMacOS;

  /// Erstellt einen SingleActivator mit dem korrekten Modifier für die Plattform.
  /// - Windows/Linux: Ctrl
  /// - macOS: Meta (⌘ Command)
  static SingleActivator withPlatformModifier(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool alt = false,
  }) {
    if (isMacOS) {
      return SingleActivator(key, meta: true, shift: shift, alt: alt);
    }
    return SingleActivator(key, control: true, shift: shift, alt: alt);
  }

  /// Erstellt einen Alt-basierten Shortcut (funktioniert auf allen Plattformen gleich).
  static SingleActivator withAlt(LogicalKeyboardKey key) {
    return SingleActivator(key, alt: true);
  }

  /// Formatiert einen Shortcut für die Anzeige im Menü.
  /// Beispiel: "Ctrl + B" oder "⌘ + B"
  static String formatShortcut(String keyName, {bool useAlt = false}) {
    final modifier = isMacOS ? '⌘' : 'Ctrl';
    if (useAlt) {
      return 'Alt + $keyName';
    }
    return '$modifier + $keyName';
  }
}

/// Vordefinierte Shortcuts für das Hauptmenü.
class MenuShortcuts {
  // Datei-Menü
  static SingleActivator get settings =>
      AppKeyboardShortcuts.withPlatformModifier(LogicalKeyboardKey.comma);

  static SingleActivator get quit =>
      AppKeyboardShortcuts.withPlatformModifier(LogicalKeyboardKey.keyQ);

  // Erstellen-Menü (Ctrl/⌘ + Shift + Buchstabe)
  static SingleActivator get createBeitrag =>
      AppKeyboardShortcuts.withPlatformModifier(
        LogicalKeyboardKey.keyB,
        shift: true,
      );

  static SingleActivator get createRechnung =>
      AppKeyboardShortcuts.withPlatformModifier(
        LogicalKeyboardKey.keyR,
        shift: true,
      );

  static SingleActivator get createMitglied =>
      AppKeyboardShortcuts.withPlatformModifier(
        LogicalKeyboardKey.keyM,
        shift: true,
      );

  static SingleActivator get createLeistung =>
      AppKeyboardShortcuts.withPlatformModifier(
        LogicalKeyboardKey.keyL,
        shift: true,
      );

  static SingleActivator get createWare =>
      AppKeyboardShortcuts.withPlatformModifier(
        LogicalKeyboardKey.keyW,
        shift: true,
      );

  // Datenübertragung-Menü
  static SingleActivator get rechnungBeitraege =>
      const SingleActivator(LogicalKeyboardKey.f1, shift: true);

  static SingleActivator get rechnungVerkauf =>
      const SingleActivator(LogicalKeyboardKey.f2, shift: true);

  static SingleActivator get backup =>
      AppKeyboardShortcuts.withPlatformModifier(LogicalKeyboardKey.keyB);

  static SingleActivator get restore =>
      AppKeyboardShortcuts.withPlatformModifier(LogicalKeyboardKey.keyR);

  static SingleActivator get csvExport =>
      AppKeyboardShortcuts.withPlatformModifier(LogicalKeyboardKey.keyE);

  static SingleActivator get csvImport =>
      AppKeyboardShortcuts.withPlatformModifier(LogicalKeyboardKey.keyI);

  // Hilfe-Menü
  static SingleActivator get help =>
      const SingleActivator(LogicalKeyboardKey.f1);

  static SingleActivator get about =>
      const SingleActivator(LogicalKeyboardKey.f2);

  // Navigation (Alt + Zahl)
  static SingleActivator dashboard(int index) {
    assert(index >= 1 && index <= 9, 'Index must be between 1 and 9');
    final key = switch (index) {
      1 => LogicalKeyboardKey.digit1,
      2 => LogicalKeyboardKey.digit2,
      3 => LogicalKeyboardKey.digit3,
      4 => LogicalKeyboardKey.digit4,
      5 => LogicalKeyboardKey.digit5,
      6 => LogicalKeyboardKey.digit6,
      7 => LogicalKeyboardKey.digit7,
      8 => LogicalKeyboardKey.digit8,
      9 => LogicalKeyboardKey.digit9,
      _ => LogicalKeyboardKey.digit1,
    };
    return AppKeyboardShortcuts.withAlt(key);
  }
}

/// Extension für einfache Shortcut-Anzeige im Menü.
extension MenuShortcutDisplay on SingleActivator {
  /// Gibt eine lesbare Darstellung des Shortcuts zurück.
  String get menuLabel {
    final parts = <String>[];
    
    if (meta) parts.add(Platform.isMacOS ? '⌘' : 'Ctrl');
    if (control) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    
    String keyName = trigger.keyLabel;
    if (keyName.startsWith('Digit')) {
      keyName = keyName.substring(5);
    } else if (keyName.startsWith('Key')) {
      keyName = keyName.substring(3);
    } else if (keyName == 'Comma') {
      keyName = ',';
    }
    
    parts.add(keyName);
    return parts.join(' + ');
  }
}

/// Extension für einfache Shortcut-Formatierung.
extension ShortcutDisplay on SingleActivator {
  /// Gibt eine lesbare Darstellung des Shortcuts zurück.
  String get displayLabel {
    final buffer = StringBuffer();

    if (meta) buffer.write(Platform.isMacOS ? '⌘ ' : 'Ctrl ');
    if (control) buffer.write('Ctrl ');
    if (alt) buffer.write('Alt ');
    if (shift) buffer.write('Shift ');

    String keyName = trigger.keyLabel;
    if (keyName.startsWith('Digit')) {
      keyName = keyName.substring(5);
    } else if (keyName.startsWith('Key')) {
      keyName = keyName.substring(3);
    }

    buffer.write(keyName);
    return buffer.toString().trim();
  }
}
