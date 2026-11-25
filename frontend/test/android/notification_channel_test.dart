import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Comprueba, leyendo los archivos como texto (la prueba corre desde
/// `frontend/`), que la app de Android crea el canal de avisos con el mismo id
/// que manda el backend y que el manifiesto y el ícono apuntan a él.
void main() {
  const kotlinPath =
      'android/app/src/main/kotlin/uy/edu/fing/tecnoinf/mvd/a2026_sem2_grupo4/'
      'agenda_medica/MainActivity.kt';
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const iconPath = 'android/app/src/main/res/drawable/ic_stat_notification.xml';

  final kotlin = File(kotlinPath).readAsStringSync();
  final manifest = File(manifestPath).readAsStringSync();

  /// Los atributos de cada `<meta-data .../>` del manifiesto, por nombre.
  Map<String, Map<String, String>> metaData() {
    final result = <String, Map<String, String>>{};
    for (final tag in RegExp(r'<meta-data([^>]*)/>').allMatches(manifest)) {
      final attributes = {
        for (final a in RegExp(
          r'android:(\w+)\s*=\s*"([^"]*)"',
        ).allMatches(tag.group(1)!))
          a.group(1)!: a.group(2)!,
      };
      result[attributes['name']!] = attributes;
    }
    return result;
  }

  group('MainActivity.kt', () {
    test('crea el canal avisos_consultas con importancia alta', () {
      expect(kotlin, contains('"avisos_consultas"'));
      expect(kotlin, contains('createNotificationChannel'));
      expect(kotlin, contains('IMPORTANCE_HIGH'));
      expect(kotlin, isNot(contains('IMPORTANCE_DEFAULT')));
    });

    test('el canal se llama "Avisos de consultas"', () {
      expect(kotlin, contains('"Avisos de consultas"'));
    });

    test('el canal tiene una descripción en español', () {
      expect(kotlin, contains('Avisos sobre tus consultas e historia clínica'));
    });

    test('crea el canal después de llamar a super.onCreate', () {
      final superCall = kotlin.indexOf('super.onCreate');
      final create = kotlin.indexOf('createNotificationChannel');

      expect(superCall, isNonNegative);
      expect(create, greaterThan(superCall));
    });

    test('el id es una constante que dice que coincide con el backend', () {
      expect(kotlin, contains('const val CHANNEL_ID = "avisos_consultas"'));
      expect(kotlin, contains('docs/api/railway-correo.md'));
    });
  });

  group('AndroidManifest.xml', () {
    test('declara el canal por defecto de Firebase Messaging', () {
      final meta = metaData();

      expect(
        meta['com.google.firebase.messaging.default_notification_channel_id']!['value'],
        'avisos_consultas',
      );
    });

    test('declara el ícono por defecto de Firebase Messaging', () {
      final meta = metaData();

      expect(
        meta['com.google.firebase.messaging.default_notification_icon']!['resource'],
        '@drawable/ic_stat_notification',
      );
    });

    test('las dos meta-data están dentro de <application>', () {
      final open = manifest.indexOf('<application');
      final close = manifest.indexOf('</application>');
      final channel = manifest.indexOf(
        'com.google.firebase.messaging.default_notification_channel_id',
      );
      final icon = manifest.indexOf(
        'com.google.firebase.messaging.default_notification_icon',
      );

      expect(channel, allOf(greaterThan(open), lessThan(close)));
      expect(icon, allOf(greaterThan(open), lessThan(close)));
    });

    test('el filtro de arranque y los permisos siguen como estaban', () {
      expect(manifest, contains('android.intent.action.MAIN'));
      expect(manifest, contains('android.intent.category.LAUNCHER'));
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.INTERNET'));
    });
  });

  group('ic_stat_notification.xml', () {
    test('existe y es un vector de 24 dp', () {
      final file = File(iconPath);

      expect(file.existsSync(), isTrue);
      final xml = file.readAsStringSync();
      expect(xml, contains('<vector'));
      expect(xml, contains('android:width="24dp"'));
      expect(xml, contains('android:height="24dp"'));
      expect(xml, contains('android:viewportWidth="24"'));
      expect(xml, contains('android:viewportHeight="24"'));
    });

    test('todo lo que dibuja es blanco', () {
      final xml = File(iconPath).readAsStringSync();
      final colors = RegExp(
        r'android:(?:fillColor|strokeColor)\s*=\s*"([^"]*)"',
      ).allMatches(xml).map((m) => m.group(1)).toList();

      expect(colors, isNotEmpty);
      expect(colors, everyElement('#FFFFFFFF'));
    });

    test('no usa degradados ni atributos de tema', () {
      final xml = File(iconPath).readAsStringSync();

      expect(xml, isNot(contains('<gradient')));
      expect(xml, isNot(contains('aapt:attr')));
      expect(xml, isNot(contains('?attr/')));
      expect(xml, isNot(contains('android:tint')));
    });

    test('tiene al menos un trazo y es XML bien cerrado', () {
      final xml = File(iconPath).readAsStringSync();

      expect(RegExp(r'<path\b').allMatches(xml), isNotEmpty);
      expect(xml.trim(), endsWith('</vector>'));
    });
  });

  test('el id del canal es el mismo en el Kotlin y en el manifiesto', () {
    final kotlinId = RegExp(r'const val CHANNEL_ID = "([^"]+)"')
        .firstMatch(kotlin)!
        .group(1);
    final manifestId =
        metaData()['com.google.firebase.messaging.default_notification_channel_id']!['value'];

    expect(kotlinId, 'avisos_consultas');
    expect(manifestId, kotlinId);
  });
}
