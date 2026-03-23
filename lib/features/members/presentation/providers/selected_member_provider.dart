import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_member_provider.g.dart';

/// Provider to persist the selected member ID across navigation.
/// This ensures that when the user switches to another screen and back,
/// the previously selected member is restored.
@Riverpod(keepAlive: true)
class SelectedMemberId extends _$SelectedMemberId {
  @override
  int? build() => null;

  void select(int? id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}
