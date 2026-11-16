import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/intercept_back_provider.dart';
import 'package:agenda_medica/features/auth/providers/password_recovery_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_password_recovery_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart' show goTo, locationOf;

/// En una prueba de widget `kIsWeb` es siempre `false`, así que no se puede
/// probar la web cambiando la plataforma. La decisión de interceptar el atrás
/// vive en `interceptSystemBackProvider` (por defecto `!kIsWeb`); acá se la
/// apaga a mano, que es el valor que da en la web.
Future<ProviderContainer> _pumpWithoutIntercept(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      interceptSystemBackProvider.overrideWithValue(false),
      authRepositoryProvider.overrideWith(
        (ref) async => FakeAuthRepository(
          ref.read(sessionProvider.notifier),
          latency: Duration.zero,
        ),
      ),
      firstLoginRepositoryProvider.overrideWith(
        (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
      ),
      passwordRecoveryRepositoryProvider.overrideWith(
        (ref) async => FakePasswordRecoveryRepository(latency: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(goRouterProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('por defecto se intercepta el atrás fuera de la web', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(interceptSystemBackProvider), isTrue);
  });

  for (final path in const [
    '/primer-ingreso/solicitar?acceso=empleado',
    '/recuperacion/solicitar?acceso=empleado',
    '/primer-ingreso?token=abc123',
    '/recuperacion?token=abc123',
  ]) {
    testWidgets('sin interceptar (web) el atrás en $path no navega a mano', (
      tester,
    ) async {
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final container = await _pumpWithoutIntercept(tester);
      await goTo(tester, container, path);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Sin la intercepción el atrás cae en el comportamiento de go_router:
      // la pila tiene una sola página, así que no hay a dónde volver.
      expect(locationOf(container), path);
      expect(exits, 1);
    });
  }
}
