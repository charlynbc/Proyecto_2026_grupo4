import 'dart:async';

import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
import 'package:agenda_medica/features/notificaciones/providers/push_registration_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/device_repository.dart';
import 'package:agenda_medica/features/notificaciones/services/push_registration_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import '../notificaciones/push_test_support.dart';

/// Un [AuthRepository] que anota el cierre de sesión en la misma lista que
/// el repositorio de dispositivos, para comprobar el orden entre los dos.
class _OrderedAuthRepository implements AuthRepository {
  _OrderedAuthRepository(this.events);

  final List<String> events;

  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> logout() async => events.add('logout');
}

final _routes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (_, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Pantalla'),
        actions: const [LogoutButton()],
      ),
    ),
  ),
];

/// Monta el botón con un controlador real (servicio y dispositivos falsos que
/// anotan en [events]). Con [registered] el controlador ya tiene un token.
Future<void> _pump(
  WidgetTester tester, {
  required List<String> events,
  DeviceRepository? devices,
  bool registered = true,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final controller = PushRegistrationController(
    service: FakePushService(),
    devices: () async => devices ?? RecordingDeviceRepository(events: events),
    deactivateTimeout: timeout,
  );
  addTearDown(controller.stop);
  if (registered) await controller.start();
  events.clear();

  await pumpAdminScreens(
    tester,
    routes: _routes,
    initialLocation: '/',
    overrides: [
      authRepositoryProvider.overrideWith(
        (ref) async => _OrderedAuthRepository(events),
      ),
      pushRegistrationControllerProvider.overrideWithValue(controller),
    ],
  );
}

Future<void> _confirmLogout(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cerrar sesión'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
  await tester.pump();
}

void main() {
  testWidgets('la baja del token se llama antes de cerrar la sesión', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(tester, events: events);

    await _confirmLogout(tester);
    await tester.pumpAndSettle();

    expect(events, ['deactivate:fcm-token-1', 'logout']);
  });

  testWidgets('si la baja falla, la sesión se cierra igual', (tester) async {
    final events = <String>[];
    await _pump(
      tester,
      events: events,
      devices: RecordingDeviceRepository(
        events: events,
        error: const DeviceException(DeviceFailure.other),
      ),
    );

    await _confirmLogout(tester);
    await tester.pumpAndSettle();

    expect(events, ['deactivate:fcm-token-1', 'logout']);
  });

  testWidgets(
    'si la baja no responde, la sesión se cierra al vencer el timeout',
    (tester) async {
      final events = <String>[];
      await _pump(
        tester,
        events: events,
        devices: RecordingDeviceRepository(
          events: events,
          hang: Completer<void>(),
        ),
        timeout: const Duration(milliseconds: 500),
      );

      await _confirmLogout(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(events, ['deactivate:fcm-token-1']);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(events, ['deactivate:fcm-token-1', 'logout']);
    },
  );

  testWidgets('sin token registrado (un empleado) solo cierra la sesión', (
    tester,
  ) async {
    final events = <String>[];
    await _pump(tester, events: events, registered: false);

    await _confirmLogout(tester);
    await tester.pumpAndSettle();

    expect(events, ['logout']);
  });
}
