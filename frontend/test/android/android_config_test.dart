import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Comprueba la configuración de Android que pide el push (RNF-23) y la
/// compatibilidad mínima (RNF-04). Los tests corren desde `frontend/`.
String _read(String path) => File(path).readAsStringSync();

void main() {
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  final appGradle = _read('android/app/build.gradle.kts');
  final settingsGradle = _read('android/settings.gradle.kts');

  test('el manifest principal pide el permiso de INTERNET', () {
    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"'),
    );
  });

  test('el manifest pide POST_NOTIFICATIONS (Android 13 o más)', () {
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"',
      ),
    );
  });

  test('minSdk es 26 o más (RNF-04: Android 8.0)', () {
    final match = RegExp(r'minSdk\s*=\s*(?:maxOf\()?(\d+)')
        .firstMatch(appGradle);

    expect(
      match,
      isNotNull,
      reason: 'No se encontró minSdk fijo en build.gradle.kts',
    );
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(26));
  });

  test('settings declara el plugin de google-services sin aplicarlo', () {
    expect(
      settingsGradle,
      contains('id("com.google.gms.google-services") version'),
    );
    expect(
      RegExp(r'id\("com\.google\.gms\.google-services"\)[^\n]*apply false')
          .hasMatch(settingsGradle),
      isTrue,
    );
  });

  test('la app aplica google-services solo si existe google-services.json', () {
    expect(
      RegExp(
        r'if \(file\("google-services\.json"\)\.exists\(\)\) \{\s*apply\(plugin = "com\.google\.gms\.google-services"\)',
      ).hasMatch(appGradle),
      isTrue,
    );
  });
}
