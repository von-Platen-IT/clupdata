import 'package:uuid/uuid.dart';

/// Hilfsfunktion zur Generierung einer UUID v4.
///
/// Diese Funktion wird von den Drift-Tabellen-Definitionen in `clientDefault`
/// verwendet. Sie muss als globale Funktion deklariert sein, damit Drift's
/// Code-Generator sie in der `.g.dart` Datei referenzieren kann.
///
/// Verwendung in Tabellen:
/// ```dart
/// TextColumn get uuid =>
///     text().unique().clientDefault(() => generateUuid())();
/// ```
String generateUuid() => const Uuid().v4();
