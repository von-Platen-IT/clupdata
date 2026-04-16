import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_menu_item_provider.g.dart';

/// Provider für den aktuell ausgewählten Menüpunkt im Hauptmenü.
/// Wird verwendet um den Text im Hauptbereich anzuzeigen.
@riverpod
class ActiveMenuItem extends _$ActiveMenuItem {
  @override
  String? build() => null;

  void setActiveItem(String item) {
    state = item;
  }

  void clear() {
    state = null;
  }
}
