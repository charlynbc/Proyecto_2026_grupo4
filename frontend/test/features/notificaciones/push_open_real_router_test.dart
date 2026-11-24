import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_shell.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_detail_screen.dart';
import 'package:agenda_medica/features/notificaciones/models/push_tap.dart';
import 'package:agenda_medica/features/notificaciones/providers/device_repository_provider.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/providers/push_notification_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/screens/notifications_screen.dart';
import 'package:agenda_medica/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'push_test_support.dart';

/// Un socio que ya tiene la sesión iniciada al abrir la app.
class _SocioSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'prueba-socio',
    role: UserRole.socio,
  );
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

/// Monta el `MyApp` real (su router, su sesión y el manejo de los push) con
/// repositorios falsos y el servicio de push de prueba. Con [loggedIn] el socio
/// ya tiene la sesión iniciada; sin él la app termina en el login.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required FakePushService service,
  bool loggedIn = true,
}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        employeeAccessAvailableProvider.overrideWithValue(true),
        if (loggedIn) sessionProvider.overrideWith(_SocioSession.new),
        authRepositoryProvider.overrideWith(
          (ref) async => FakeAuthRepository(
            ref.read(sessionProvider.notifier),
            latency: Duration.zero,
          ),
        ),
        firstLoginRepositoryProvider.overrideWith(
          (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
        ),
        deviceRepositoryProvider.overrideWith(
          (ref) async => RecordingDeviceRepository(),
        ),
        pushNotificationServiceProvider.overrideWithValue(service),
        notificationRepositoryProvider.overrideWith(
          (ref) async => FakeNotificationRepository(latency: Duration.zero),
        ),
        medicalHistoryRepositoryProvider.overrideWith(
          (ref) async => FakeMedicalHistoryRepository(latency: Duration.zero),
        ),
      ],
      child: const MyApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MyApp)));
}

String _path(WidgetTester tester) =>
    GoRouterState.of(tester.element(find.byType(Scaffold).first)).uri.path;

// La atención 12 de la historia falsa es "Control cardiovascular".
const _historiaConAtencion = PushTap(
  type: 'HISTORIA_ACTUALIZADA',
  notificationId: 15002,
  atencionId: 12,
);

void main() {
  testWidgets('un toque de historia con atención abre el detalle y al volver '
      'queda Avisos', (tester) async {
    final service = FakePushService();
    await _pumpApp(tester, service: service);

    service.tapEvents.add(_historiaConAtencion);
    await _settle(tester);

    final detail = find.byType(MedicalHistoryDetailScreen);
    expect(detail, findsOneWidget);
    expect(tester.widget<MedicalHistoryDetailScreen>(detail).id, 12);
    expect(find.text('Control cardiovascular'), findsOneWidget);
    expect(_path(tester), '/socio/historia/12');
    // Avisos quedó debajo y el shell no se duplicó.
    expect(
      find.byType(NotificationsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);

    await tester.tap(
      find.descendant(of: detail, matching: find.byType(BackButton)),
    );
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(_path(tester), '/socio/avisos');
  });

  testWidgets('el toque con el que se abrió la app cerrada abre el detalle', (
    tester,
  ) async {
    final service = FakePushService()..initialTap = _historiaConAtencion;
    await _pumpApp(tester, service: service);

    expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
    expect(_path(tester), '/socio/historia/12');

    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(_path(tester), '/socio/avisos');
  });

  testWidgets('un toque de otro tipo abre solo Avisos', (tester) async {
    final service = FakePushService();
    await _pumpApp(tester, service: service);

    service.tapEvents.add(const PushTap(type: 'AGENDA', notificationId: 15001));
    await _settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(_path(tester), '/socio/avisos');
  });

  testWidgets('un toque de historia sin atención abre solo Avisos', (
    tester,
  ) async {
    final service = FakePushService();
    await _pumpApp(tester, service: service);

    service.tapEvents.add(
      const PushTap(type: 'HISTORIA_ACTUALIZADA', notificationId: 15002),
    );
    await _settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
  });

  testWidgets('un toque sin sesión espera al login del socio y después abre '
      'el detalle', (tester) async {
    final service = FakePushService();
    final container = await _pumpApp(tester, service: service, loggedIn: false);
    expect(find.byType(NotificationsScreen), findsNothing);

    service.tapEvents.add(_historiaConAtencion);
    await _settle(tester);
    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);

    container
        .read(sessionProvider.notifier)
        .setAuthenticated(accessToken: 'access-token', role: UserRole.socio);
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
    expect(_path(tester), '/socio/historia/12');

    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('si se autentica otro rol el destino pendiente se descarta', (
    tester,
  ) async {
    final service = FakePushService();
    final container = await _pumpApp(tester, service: service, loggedIn: false);

    service.tapEvents.add(_historiaConAtencion);
    await _settle(tester);

    container
        .read(sessionProvider.notifier)
        .setAuthenticated(accessToken: 'access-token', role: UserRole.medico);
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(_path(tester), isNot(startsWith('/socio')));
  });
}
