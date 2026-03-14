import 'package:flutter/services.dart';

/// Utility-Klasse zum Auslesen der App-Version aus pubspec.yaml
class AppVersion {
  static String? _cachedVersion;

  /// Gibt die App-Version aus pubspec.yaml zurück (z.B. "1.0.0")
  static Future<String> getVersion() async {
    if (_cachedVersion != null) {
      return _cachedVersion!;
    }

    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final versionLine = pubspec
          .split('\n')
          .firstWhere(
            (line) => line.trim().startsWith('version:'),
            orElse: () => 'version: 1.0.0',
          );
      // Format: "version: 1.0.0+1" -> extrahiere "1.0.0"
      final versionPart = versionLine.split(':')[1].trim();
      _cachedVersion = versionPart.split('+')[0];
      return _cachedVersion!;
    } catch (e) {
      return '1.0.0';
    }
  }

  /// Gibt die Version mit v-Präfix zurück (z.B. "v1.0.0")
  static Future<String> getVersionWithPrefix() async {
    final version = await getVersion();
    return 'v$version';
  }
}
