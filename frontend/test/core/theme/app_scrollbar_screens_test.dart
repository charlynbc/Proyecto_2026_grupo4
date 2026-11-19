import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/real_app.dart';
import '../../helpers/scrollbar_probe.dart';

/// Las pantallas principales, con la app de verdad (tema y ScrollBehavior de
/// `main.dart`) y datos falsos. Ninguna prueba toca la pantalla ni pasa el
/// mouse: la barra tiene que verse sola.
final _screens = <(String, UserRole, String)>[
  ('Inicio del socio', UserRole.socio, '/socio/inicio'),
  ('Inicio del administrador', UserRole.administrador, '/admin/inicio'),
  ('Inicio del funcionario', UserRole.funcionario, '/funcionario/inicio'),
  ('Cartelera del administrador', UserRole.administrador, '/admin/cartelera'),
  ('Estadísticas', UserRole.administrador, '/admin/estadisticas'),
  ('Usuarios del administrador', UserRole.administrador, '/admin/usuarios'),
  ('Publicar una novedad', UserRole.administrador, '/admin/cartelera/nueva'),
];

void main() {
  setUpAll(loadRoboto);

  group('con la pantalla baja la barra se ve sola', () {
    for (final (name, role, path) in _screens) {
      testWidgets(name, (tester) async {
        await pumpRealAppAs(tester, role, path, size: const Size(360, 300));
        await settleScrollbars(tester);

        final bars = drawnVerticalScrollbars(tester);
        expect(bars, hasLength(1), reason: '$name a 360 x 300');
        expect(bars.single.thumbColor, isSameColorAs(const Color(0xFF5C6370)));
        expect(bars.single.thumb!.width, 10);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('con la pantalla alta y el contenido completo no hay barra', () {
    for (final (name, role, path) in _screens) {
      testWidgets(name, (tester) async {
        await pumpRealAppAs(tester, role, path, size: const Size(1000, 6000));
        await settleScrollbars(tester);

        expect(
          drawnVerticalScrollbars(tester),
          isEmpty,
          reason: '$name a 1000 x 6000',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('a 320 px de ancho y con el texto al doble', () {
    for (final (name, role, path) in _screens) {
      testWidgets(name, (tester) async {
        await pumpRealAppAs(
          tester,
          role,
          path,
          size: const Size(320, 560),
          textScale: 2,
        );
        await settleScrollbars(tester);

        final bars = drawnVerticalScrollbars(tester);
        expect(bars, hasLength(1), reason: '$name a 320 x 560');
        expect(bars.single.thumb!.right, lessThanOrEqualTo(320));
        expect(bars.single.thumb!.left, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Estadísticas: cada pestaña tiene su barra y cambiar no falla', () {
    const tabs = [
      'stats-tab-specialties',
      'stats-tab-shifts',
      'stats-tab-appointments',
      'stats-tab-absences',
      'stats-tab-referrals',
      'stats-tab-time-slots',
    ];

    for (final size in [const Size(900, 520), const Size(320, 400)]) {
      testWidgets('con ${size.width.toInt()} px de ancho', (tester) async {
        await pumpRealAppAs(
          tester,
          UserRole.administrador,
          '/admin/estadisticas',
          size: size,
          textScale: size.width == 320 ? 2 : 1,
        );

        for (final key in tabs) {
          await tester.tap(find.byKey(Key(key)));
          await tester.pump();
          // En medio de la animación hay dos pestañas montadas a la vez.
          await tester.pump(const Duration(milliseconds: 120));
          expect(tester.takeException(), isNull, reason: 'cambiando a $key');
          await tester.pumpAndSettle();
          await settleScrollbars(tester);

          expect(drawnVerticalScrollbars(tester), hasLength(1), reason: key);
          expect(tester.takeException(), isNull, reason: key);
        }
      });
    }

    testWidgets('el scroll horizontal de Franjas no suma una barra', (
      tester,
    ) async {
      await pumpRealAppAs(
        tester,
        UserRole.administrador,
        '/admin/estadisticas',
        size: const Size(400, 6000),
      );

      await tester.tap(find.byKey(const Key('stats-tab-time-slots')));
      await tester.pumpAndSettle();
      await settleScrollbars(tester);

      expect(drawnHorizontalScrollbars(tester), isEmpty);
    });
  });
}
