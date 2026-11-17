import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
import 'package:agenda_medica/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';

/// Cambiar el ancho de la ventana en vivo, sin recargar, pasa por anchos
/// minúsculos (hasta 1 px) mientras el navegador redimensiona. La fila de
/// íconos del AppBar del Inicio no puede desbordarse en ninguno de esos pasos.

String _pending(WidgetTester tester) {
  final found = <String>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    found.add(error.toString().split('\n').first);
  }
  return found.join(' | ');
}

Future<void> _resize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, width < 700 ? 700 : 800);
  await tester.pump();
}

void main() {
  setUpAll(loadRoboto);

  Future<void> openHome(
    WidgetTester tester, {
    UserRole role = UserRole.socio,
  }) async {
    final container = await pumpApp(tester, size: const Size(1280, 800));
    final person = TestData.people.firstWhere((p) => p.role == role.apiValue);
    final repo = await container.read(authRepositoryProvider.future);
    final login = repo.login(
      ci: person.ci,
      password: kTestPassword,
      access: AccessType.forRole(role),
    );
    await tester.pumpAndSettle();
    await login;
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_pending(tester), isEmpty, reason: 'antes de achicar');
  }

  Size iconsSize(WidgetTester tester) =>
      tester.getSize(find.byType(LogoutButton));

  group('el Inicio del socio al cambiar el ancho sin recargar', () {
    testWidgets('1280, 320 y de vuelta, sin excepciones', (tester) async {
      await openHome(tester);

      for (final width in [320.0, 1280.0, 320.0, 1280.0]) {
        await _resize(tester, width);
        expect(_pending(tester), isEmpty, reason: 'ancho $width, pump');
        await tester.pumpAndSettle();
        expect(_pending(tester), isEmpty, reason: 'ancho $width, settle');
      }
      await unmountApp(tester);
    });

    testWidgets('con pasos intermedios de 100, 40 y 1 px, sin excepciones', (
      tester,
    ) async {
      await openHome(tester);

      for (final width in [100.0, 40.0, 1.0, 40.0, 100.0, 320.0, 1280.0]) {
        await _resize(tester, width);
        expect(_pending(tester), isEmpty, reason: 'ancho $width, pump');
        await tester.pumpAndSettle();
        expect(_pending(tester), isEmpty, reason: 'ancho $width, settle');
      }
      await unmountApp(tester);
    });

    testWidgets('con 40 y 1 px la fila de íconos cabe en el ancho', (
      tester,
    ) async {
      await openHome(tester);

      for (final width in [40.0, 1.0]) {
        await _resize(tester, width);
        await tester.pumpAndSettle();
        expect(_pending(tester), isEmpty, reason: 'ancho $width');
        expect(
          tester.getRect(find.byType(LogoutButton)).right,
          lessThanOrEqualTo(width),
          reason: 'ancho $width',
        );
        expect(iconsSize(tester).width, lessThanOrEqualTo(width));
      }
      await unmountApp(tester);
    });

    testWidgets('a 320 y a 1280 px los dos íconos miden lo de siempre: 96 x '
        '48', (tester) async {
      await openHome(tester);
      expect(iconsSize(tester), const Size(96, 48));

      await _resize(tester, 320);
      await tester.pumpAndSettle();
      expect(iconsSize(tester), const Size(96, 48));

      // Después de pasar por 1 px vuelven a su tamaño completo.
      await _resize(tester, 1);
      await tester.pumpAndSettle();
      await _resize(tester, 320);
      await tester.pumpAndSettle();
      expect(iconsSize(tester), const Size(96, 48));
      await _resize(tester, 1280);
      await tester.pumpAndSettle();
      expect(iconsSize(tester), const Size(96, 48));
      expect(_pending(tester), isEmpty);
      await unmountApp(tester);
    });

    testWidgets('con 40 y 1 px los íconos se achican en proporción al ancho', (
      tester,
    ) async {
      await openHome(tester);

      // 96 px de íconos en 40 px de ancho es escala 40 / 96, o sea 20 px por
      // ícono; en 1 px, 1 / 96 de 48 px son 0,5 px.
      final account = find.byKey(const Key('open-account'));
      await _resize(tester, 40);
      await tester.pumpAndSettle();
      expect(tester.getRect(account).width, closeTo(20, 0.01));
      expect(tester.getRect(account).height, closeTo(20, 0.01));
      await _resize(tester, 1);
      await tester.pumpAndSettle();
      expect(tester.getRect(account).width, closeTo(0.5, 0.01));
      await unmountApp(tester);
    });

    testWidgets('los dos íconos siguen con su texto de ayuda', (tester) async {
      await openHome(tester);

      expect(find.byTooltip('Mi cuenta'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      await _resize(tester, 1);
      await tester.pumpAndSettle();
      await _resize(tester, 320);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mi cuenta'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      await unmountApp(tester);
    });
  });
}
