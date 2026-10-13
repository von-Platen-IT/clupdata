import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/open.dart';

/// Konfiguriert den sqlite3-Bibliotheks-Ladevorgang.
///
/// Linux-Systeme haben oft nur `libsqlite3.so.0` (ohne Dev-Link `.so`),
/// sodass die Standard-Suche nach `libsqlite3.so` fehlschlägt.
///
/// **Wichtig**: Muss vor dem ersten Datenbankzugriff aufgerufen werden –
/// und in **jedem Isolate**, das eine Drift-Datenbank öffnet
/// ([`NativeDatabase.createInBackground`] spawnt ein Hintergrund-Isolate!).
/// Drift bietet dafür den `isolateSetup`-Callback.
void configureSqlite() {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => ffi.DynamicLibrary.open('libsqlite3.so.0'),
    );
    debugPrint('[sqlite3] Library-Override aktiv: libsqlite3.so.0');
  }
}
