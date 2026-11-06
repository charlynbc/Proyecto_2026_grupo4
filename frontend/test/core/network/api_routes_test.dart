import 'dart:io';

import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reemplaza los segmentos variables (`{id}`, `{idAtencion}` o un número) por
/// `{id}`, para comparar las rutas del código con las del registro.
String _normalize(String route) => route
    .split('?')
    .first
    .split('/')
    .map((s) => (s.startsWith('{') || int.tryParse(s) != null) ? '{id}' : s)
    .join('/');

void main() {
  group('ApiRoutes', () {
    test('todas las rutas empiezan con /api/', () {
      for (final route in ApiRoutes.all) {
        expect(route, startsWith('/api/'), reason: route);
      }
    });

    test('no hay rutas repetidas', () {
      expect(ApiRoutes.all.toSet().length, ApiRoutes.all.length);
    });

    test(
      'validar enlaces y cartelera (filas 63 a 67), valores escritos a mano',
      () {
        expect(
          ApiRoutes.authFirstLoginValidate,
          '/api/auth/primer-ingreso/validar',
        );
        expect(
          ApiRoutes.authPasswordRecoveryValidate,
          '/api/auth/recuperacion/validar',
        );
        expect(ApiRoutes.announcements, '/api/anuncios');
        expect(ApiRoutes.announcement(42), '/api/anuncios/42');
      },
    );

    test('cubren las rutas de docs/api/endpoints-usados.md', () {
      final file = File('../docs/api/endpoints-usados.md');
      if (!file.existsSync()) {
        markTestSkipped('No se encontró docs/api/endpoints-usados.md');
        return;
      }
      final documented =
          RegExp(r'`(?:GET|POST|PATCH|PUT|DELETE) (/api/[^`\s]+)`')
              .allMatches(file.readAsStringSync())
              .map((m) => _normalize(m.group(1)!))
              .toSet();
      final inCode = ApiRoutes.all.map(_normalize).toSet();

      expect(documented, isNotEmpty);
      expect(documented.difference(inCode), isEmpty);
    });
  });
}
