import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_action_provider.g.dart';

/// Ein registrierter Erstellen-Aktionseintrag für das Menü.
class CreateActionEntry {
  final String label;
  final void Function(BuildContext context) action;

  const CreateActionEntry({required this.label, required this.action});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateActionEntry && label == other.label;

  @override
  int get hashCode => label.hashCode;
}

/// Riverpod-basierte Registry für Erstellen-Aktionen.
/// Features registrieren ihre Aktionen hier, MainMenuBar konsumiert sie.
/// Verletzt nicht das Open/Closed Principle, da MainMenuBar nicht geändert
/// werden muss, wenn neue Features hinzukommen (Issue 4.1).
@Riverpod(keepAlive: true)
class CreateActionRegistry extends _$CreateActionRegistry {
  @override
  List<CreateActionEntry> build() => [];

  /// Registriert eine neue Erstellen-Aktion.
  /// Wenn bereits ein Eintrag mit demselben Label existiert, wird er ersetzt.
  void register(CreateActionEntry entry) {
    final existing = state.where((e) => e.label == entry.label).firstOrNull;
    if (existing != null) {
      state = state.map((e) => e.label == entry.label ? entry : e).toList();
    } else {
      state = [...state, entry];
    }
  }

  /// Entfernt eine Erstellen-Aktion anhand ihres Labels.
  void unregister(String label) {
    state = state.where((e) => e.label != label).toList();
  }
}
