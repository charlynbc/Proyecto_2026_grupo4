import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/notificaciones/providers/device_repository_provider.dart';
import 'package:agenda_medica/features/notificaciones/providers/push_notification_provider.dart';
import 'package:agenda_medica/features/notificaciones/services/push_notification_service.dart';
import 'package:agenda_medica/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'push_test_support.dart';

/// Monta el `MyApp` real con repositorios falsos. Con [service] reemplaza el
/// servicio de push; sin él queda el que elige el provider (con
/// `USE_FAKES`, el que no hace nada).
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required RecordingDeviceRepository devices,
  PushNotificationService? service,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
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
        deviceRepositoryProvider.overrideWith((ref) async => devices),
        if (service != null)
          pushNotificationServiceProvider.overrideWithValue(service),
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MyApp)));
}

Future<void> _signIn(
  WidgetTester tester,
  ProviderContainer container,
  UserRole role,
) async {
  container
      .read(sessionProvider.notifier)
      .setAuthenticated(accessToken: 'access-token', role: role);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('un socio que inicia sesión registra el token del dispositivo', (
    tester,
  ) async {
    final devices = RecordingDeviceRepository();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: FakePushService(),
    );

    await _signIn(tester, container, UserRole.socio);

    expect(devices.events, ['register:fcm-token-1']);
    await unmountApp(tester);
  });

  testWidgets('un empleado que inicia sesión no registra ningún dispositivo', (
    tester,
  ) async {
    for (final role in [
      UserRole.funcionario,
      UserRole.medico,
      UserRole.administrador,
    ]) {
      final devices = RecordingDeviceRepository();
      final service = FakePushService();
      final container = await _pumpApp(
        tester,
        devices: devices,
        service: service,
      );

      await _signIn(tester, container, role);

      expect(devices.events, isEmpty, reason: role.name);
      expect(service.tokenRequests, 0, reason: role.name);
      await unmountApp(tester);
    }
  });

  testWidgets('con USE_FAKES y el servicio real no registra ni pide permiso', (
    tester,
  ) async {
    final devices = RecordingDeviceRepository();
    final container = await _pumpApp(tester, devices: devices);

    expect(
      container.read(pushNotificationServiceProvider),
      isA<NoopPushNotificationService>(),
    );
    await _signIn(tester, container, UserRole.socio);

    expect(devices.events, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('si Firebase renueva el token, lo registra de nuevo', (
    tester,
  ) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.socio);

    service.refreshes.add('fcm-token-2');
    await tester.pumpAndSettle();

    expect(devices.events, ['register:fcm-token-1', 'register:fcm-token-2']);
    await unmountApp(tester);
  });

  testWidgets('al terminar la sesión ya no se registran renovaciones', (
    tester,
  ) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.socio);
    devices.events.clear();

    container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();
    service.refreshes.add('fcm-token-2');
    await tester.pumpAndSettle();

    expect(devices.events, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('un socio cuya sesión vence borra el token de Firebase una vez '
      'y no llama a la baja', (tester) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.socio);
    devices.events.clear();

    container.read(sessionProvider.notifier).clear(expired: true);
    await tester.pumpAndSettle();

    expect(service.deleteTokenCalls, 1);
    expect(devices.events, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('el cierre de sesión voluntario da de baja con sesión y no '
      'borra el token de Firebase', (tester) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.socio);
    devices.events.clear();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(devices.events, ['deactivate:fcm-token-1']);
    expect(service.deleteTokenCalls, 0);
    await unmountApp(tester);
  });

  testWidgets('una sesión de socio que se cierra sin vencer no borra el '
      'token de Firebase', (tester) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.socio);

    container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(service.deleteTokenCalls, 0);
    await unmountApp(tester);
  });

  testWidgets('un empleado cuya sesión vence no borra el token de Firebase', (
    tester,
  ) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.funcionario);

    container.read(sessionProvider.notifier).clear(expired: true);
    await tester.pumpAndSettle();

    expect(service.deleteTokenCalls, 0);
    expect(devices.events, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('un mensaje en primer plano se muestra con título y cuerpo', (
    tester,
  ) async {
    final devices = RecordingDeviceRepository();
    final service = FakePushService();
    final container = await _pumpApp(
      tester,
      devices: devices,
      service: service,
    );
    await _signIn(tester, container, UserRole.socio);

    service.messages.add(
      const ForegroundPushMessage(
        title: 'Turno suspendido',
        body: 'Se suspendió el turno del 20/10/2026.',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Turno suspendido: Se suspendió el turno del 20/10/2026.'),
      findsOneWidget,
    );
    await unmountApp(tester);
  });
}
