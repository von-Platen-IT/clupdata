import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// The entry point of the ClupData application.
///
/// This function initializes the Flutter binding and configures the desktop
/// window properties (size, title, behavior) if running on a desktop platform
/// (Windows, Linux, macOS) using the `window_manager` plugin.
/// Finally, it runs the app wrapped in a Riverpod [ProviderScope].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Nur auf Desktop-Systemen initialisieren
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1400, 900),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'ClupData Boxclub Manager',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// The root widget of the ClupData application.
///
/// This [ConsumerWidget] listens to the [appRouterProvider] to configure
/// the declarative routing using `go_router`. It also sets up the global
/// application theme (light and dark mode) and reacts to the system's theme
/// preferences.
class MyApp extends ConsumerWidget {
  /// Creates the root application widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'ClupData',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Reagiert auf OS-Einstellung
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
