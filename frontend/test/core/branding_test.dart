import 'dart:convert';
import 'dart:io';

import 'package:agenda_medica/core/branding.dart';
import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

/// Archivos estáticos que `tool/sync_nombre.dart` reescribe. Los tests de
/// Flutter corren con la raíz de `frontend/` como directorio de trabajo.
const _staticFiles = [
  'web/index.html',
  'web/manifest.json',
  'android/app/src/main/AndroidManifest.xml',
  'README.md',
];

String _read(String path) => File(path).readAsStringSync();

String _firstMatch(String source, RegExp pattern) {
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'no se encontró ${pattern.pattern}');
  return match!.group(1)!;
}

void main() {
  test('1. el nombre no está vacío ni tiene espacios en los bordes', () {
    expect(kMutualistaName, isNotEmpty);
    expect(kMutualistaName, kMutualistaName.trim());
  });

  testWidgets('2. el título de la app es el nombre de la mutualista', (
    tester,
  ) async {
    // pumpApp arma su propio MaterialApp sin título; para probar el de
    // main.dart se monta MyApp con los mismos repositories falsos.
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        employeeAccessAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWith(
          (ref) async => FakeAuthRepository(
            ref.read(sessionProvider.notifier),
            latency: Duration.zero,
          ),
        ),
        firstLoginRepositoryProvider.overrideWith(
          (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, kMutualistaName);
  });

  testWidgets('3. el login muestra el nombre una sola vez', (tester) async {
    await pumpApp(tester);
    expect(find.text(kMutualistaName), findsOneWidget);
  });

  test('4. manifest.json: name y short_name', () {
    final manifest = jsonDecode(_read('web/manifest.json')) as Map;
    expect(manifest['name'], kMutualistaName);
    expect(manifest['short_name'], kMutualistaName);
  });

  test('5. index.html: title y apple-mobile-web-app-title', () {
    final html = _read('web/index.html');
    expect(
      _firstMatch(html, RegExp(r'<title>([^<]*)</title>')),
      kMutualistaName,
    );
    expect(
      _firstMatch(
        html,
        RegExp(r'<meta name="apple-mobile-web-app-title" content="([^"]*)"'),
      ),
      kMutualistaName,
    );
  });

  test('6. AndroidManifest.xml: android:label de application', () {
    final xml = _read('android/app/src/main/AndroidManifest.xml');
    final application = _firstMatch(xml, RegExp(r'(<application\b[^>]*>)'));
    expect(
      _firstMatch(application, RegExp(r'android:label="([^"]*)"')),
      kMutualistaName,
    );
  });

  test('7. README.md: la primera línea es el título', () {
    final firstLine = const LineSplitter().convert(_read('README.md')).first;
    expect(firstLine, '# $kMutualistaName');
  });

  test('8. los archivos estáticos no mezclan fines de línea', () {
    for (final path in _staticFiles) {
      final text = _read(path);
      final crlf = '\r\n'.allMatches(text).length;
      final lf = '\n'.allMatches(text).length;
      expect(
        crlf == 0 || crlf == lf,
        isTrue,
        reason: '$path mezcla fines de línea ($crlf CRLF de $lf saltos)',
      );
      expect(text.startsWith('﻿'), isFalse, reason: '$path tiene BOM');
    }
  });
}
