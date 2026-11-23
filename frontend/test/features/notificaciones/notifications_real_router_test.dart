import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_shell.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_detail_screen.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_screen.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Sin login, renovación ni bootstrap.
class _TestSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'prueba-socio',
    role: UserRole.socio,
  );
}

// El aviso 15040 trae la atención 12 de la historia falsa ("Control
// cardiovascular", 02/10/2026); el 15041 es de historia pero sin atencionId.
final _conAtencion = AppNotification(
  id: 15040,
  type: 'HISTORIA_ACTUALIZADA',
  title: 'Historia clínica actualizada',
  consultaId: 9000,
  atencionId: 12,
  content: 'Se registró la atención de tu consulta.',
  createdAt: DateTime.utc(2026, 10, 17, 15),
);

final _sinAtencion = AppNotification(
  id: 15041,
  type: 'HISTORIA_ACTUALIZADA',
  title: 'Historia clínica actualizada',
  consultaId: 9001,
  content: 'Se registró otra atención.',
  createdAt: DateTime.utc(2026, 10, 16, 15),
);

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

/// La historia falsa, pero con el detalle de toda atención respondiendo 404
/// (como si el servidor ya no la encontrara).
class _MissingDetailRepository implements MedicalHistoryRepository {
  final _fake = FakeMedicalHistoryRepository(latency: Duration.zero);

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) =>
      _fake.list(query);

  @override
  Future<MedicalHistoryEntry> get(int id) =>
      throw const MedicalHistoryNotFoundException();
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  bool detailMissing = false,
  String start = '/socio/avisos',
}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_TestSession.new),
      notificationRepositoryProvider.overrideWith(
        (ref) async => FakeNotificationRepository(
          latency: Duration.zero,
          seed: [_conAtencion, _sinAtencion],
        ),
      ),
      medicalHistoryRepositoryProvider.overrideWith(
        (ref) async => detailMissing
            ? _MissingDetailRepository()
            : FakeMedicalHistoryRepository(latency: Duration.zero),
      ),
    ],
  );
  final router = container.read(goRouterProvider);
  // Fija el destino antes del montaje para no cargar otras pantallas.
  router.go(start);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        locale: const Locale('es', 'UY'),
        supportedLocales: const [Locale('es', 'UY')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    ),
  );
  await _settle(tester);
  return router;
}

void main() {
  testWidgets('desde Avisos, un aviso con atencionId abre el detalle de esa '
      'atención y al volver queda Avisos', (tester) async {
    final router = await _pump(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-15040')));
    await _settle(tester);

    final detail = find.byType(MedicalHistoryDetailScreen);
    expect(detail, findsOneWidget);
    expect(tester.widget<MedicalHistoryDetailScreen>(detail).id, 12);
    expect(find.text('Control cardiovascular'), findsOneWidget);
    expect(find.byType(MedicalHistoryScreen), findsNothing);
    expect(
      GoRouterState.of(tester.element(detail)).uri.path,
      '/socio/historia/12',
    );
    // Avisos sigue debajo y la pantalla no duplicó el shell de navegación.
    expect(
      find.byType(NotificationsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);

    final back = find.descendant(of: detail, matching: find.byType(BackButton));
    expect(back, findsOneWidget);
    await tester.tap(back);
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(
      GoRouterState.of(tester.element(find.byType(NotificationsScreen)))
          .uri
          .path,
      '/socio/avisos',
    );
    expect(router.state.uri.path, '/socio/avisos');
  });

  testWidgets('un aviso de historia sin atencionId abre la lista y al volver '
      'queda Avisos', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('notification-15041')));
    await _settle(tester);

    expect(find.byType(MedicalHistoryScreen), findsOneWidget);
    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(find.byType(MedicalHistoryScreen), findsNothing);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('si el detalle responde 404 entrando desde Avisos, el botón '
      'lleva a la lista de la historia', (tester) async {
    final router = await _pump(tester, detailMissing: true);

    await tester.tap(find.byKey(const Key('notification-15040')));
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    final button = find.widgetWithText(
      OutlinedButton,
      'Ir a mi historia clínica',
    );
    expect(button, findsOneWidget);

    await tester.tap(button);
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(find.byType(MedicalHistoryScreen), findsOneWidget);
    expect(router.state.uri.path, '/socio/historia');
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
  });

  testWidgets('si el detalle responde 404 entrando desde la lista de la '
      'historia, el botón lleva a esa lista', (tester) async {
    final router = await _pump(
      tester,
      detailMissing: true,
      start: '/socio/historia',
    );
    expect(find.byType(MedicalHistoryScreen), findsOneWidget);

    final card = find.byKey(const ValueKey('medical-history-entry-12'));
    final open = find.descendant(
      of: card,
      matching: find.widgetWithText(OutlinedButton, 'Ver detalle'),
    );
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
    final button = find.widgetWithText(
      OutlinedButton,
      'Ir a mi historia clínica',
    );
    expect(button, findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);

    await tester.tap(button);
    await _settle(tester);

    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
    expect(find.byType(MedicalHistoryScreen), findsOneWidget);
    expect(router.state.uri.path, '/socio/historia');
    expect(find.byType(AppShell, skipOffstage: false), findsOneWidget);
  });
}
