import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_detail_screen.dart';
import 'package:agenda_medica/features/notificaciones/providers/device_repository_provider.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/screens/debug_push_screen.dart';
import 'package:agenda_medica/features/notificaciones/screens/notifications_screen.dart';
import 'package:agenda_medica/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'push_test_support.dart';

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

List<Override> _overrides({required bool useFakes}) => [
  useFakesProvider.overrideWithValue(useFakes),
  sessionProvider.overrideWith(_SocioSession.new),
  deviceRepositoryProvider.overrideWith(
    (ref) async => RecordingDeviceRepository(),
  ),
  notificationRepositoryProvider.overrideWith(
    (ref) async => FakeNotificationRepository(latency: Duration.zero),
  ),
  medicalHistoryRepositoryProvider.overrideWith(
    (ref) async => FakeMedicalHistoryRepository(latency: Duration.zero),
  ),
];

void main() {
  testWidgets('con USE_FAKES la pantalla de prueba simula el toque de un push '
      'de historia', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(useFakes: true),
        child: const MyApp(),
      ),
    );
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyApp)),
    );

    container.read(goRouterProvider).go(kDebugPushPath);
    await _settle(tester);
    expect(find.byType(DebugPushScreen), findsOneWidget);

    await tester.tap(find.text('Historia con atención 12'));
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
    expect(find.text('Control cardiovascular'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('la pantalla de prueba también simula un toque de otro tipo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(useFakes: true),
        child: const MyApp(),
      ),
    );
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyApp)),
    );
    container.read(goRouterProvider).go(kDebugPushPath);
    await _settle(tester);

    await tester.tap(find.text('Consulta agendada'));
    await _settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
  });

  test('sin USE_FAKES la ruta de prueba no existe', () {
    final container = ProviderContainer(overrides: _overrides(useFakes: false));
    addTearDown(container.dispose);

    final router = container.read(goRouterProvider);

    final paths = [
      for (final route in router.configuration.routes)
        if (route is GoRoute) route.path,
    ];
    expect(paths, isNot(contains('/debug/push')));
  });

  test('con USE_FAKES la ruta de prueba existe', () {
    final container = ProviderContainer(overrides: _overrides(useFakes: true));
    addTearDown(container.dispose);

    final router = container.read(goRouterProvider);

    final paths = [
      for (final route in router.configuration.routes)
        if (route is GoRoute) route.path,
    ];
    expect(paths, contains('/debug/push'));
  });
}
