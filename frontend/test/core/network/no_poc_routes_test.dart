import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el código de lib no usa las rutas eliminadas de la PoC', () {
    const removed = [
      '/api/profesionales',
      '/api/reservas',
      '/api/mis-reservas',
      '/api/auth/registro',
      '/api/auth/confirmar-email',
    ];
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final route in removed) {
        if (text.contains(route)) offenders.add('${file.path}: $route');
      }
    }
    expect(offenders, isEmpty);
  });
}
