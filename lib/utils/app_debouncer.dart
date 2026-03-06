import 'dart:async';
import 'package:flutter/foundation.dart';

/// A utility class to debounce actions. Ideal for wrapping text input callbacks
/// so that filtering logic or network requests only happen after the user
/// has stopped typing for a given duration.
class AppDebouncer {
  final Duration delay;
  Timer? _timer;

  AppDebouncer({this.delay = const Duration(milliseconds: 300)});

  /// Executes the given [action] after the [delay] has passed without
  /// this method being called again.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending action immediately.
  void cancel() {
    _timer?.cancel();
  }
}
