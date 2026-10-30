import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_filters_controller.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_detail_screen.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// No ejecuta login, renovación ni bootstrap.
class _TestSession extends SessionNotifier {
  _TestSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

/// Reutiliza los datos propios de RF-12 y registra los detalles solicitados.
class _RecordingRepository implements MedicalHistoryRepository {
  final _fake = FakeMedicalHistoryRepository(latency: Duration.zero);
  final List<int> requestedIds = [];

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) =>
      _fake.list(query);

  @override
  Future<MedicalHistoryEntry> get(int id) {
    requestedIds.add(id);
    return _fake.get(id);
  }
}

class _Harness {
  _Harness({
    required this.container,
    required this.router,
    required this.repository,
  });

  final ProviderContainer container;
  final GoRouter router;
  final _RecordingRepository repository;
}

_Harness _createHarness(SessionState session) {
  final repository = _RecordingRepository();
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(() => _TestSession(session)),
      medicalHistoryRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );

  return _Harness(
    container: container,
    router: container.read(goRouterProvider),
    repository: repository,
  );
}

const _memberSession = SessionState(
  status: SessionStatus.authenticated,
  accessToken: 'prueba-socio',
  role: UserRole.socio,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<_Harness> _pumpHistory(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = _createHarness(_memberSession);

  // Fija el destino antes del montaje para evitar cargar Disponibilidad.
  harness.router.go('/socio/historia');

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.router.dispose();
    harness.container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: MaterialApp.router(
        theme: appTheme,
        locale: const Locale('es', 'UY'),
        supportedLocales: const [Locale('es', 'UY')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: harness.router,
      ),
    ),
  );
  await _settle(tester);

  return harness;
}

String _pathOf(WidgetTester tester) {
  // context.push apila una ruta imperativa sobre la configuración base.
  // Consultamos la ruta de la pantalla activa, no la URI base del delegate.
  final detail = find.byType(MedicalHistoryDetailScreen);
  final screen = detail.evaluate().isNotEmpty
      ? detail
      : find.byType(MedicalHistoryScreen);
  return GoRouterState.of(tester.element(screen)).uri.path;
}

Finder _card(int id) => find.byKey(ValueKey('medical-history-entry-$id'));

Future<void> _openDetail(WidgetTester tester, int id) async {
  final button = find.descendant(
    of: _card(id),
    matching: find.widgetWithText(OutlinedButton, 'Ver detalle'),
  );
  expect(button, findsOneWidget);

  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester);
}

void main() {
  testWidgets('IDs inválidos redirigen al listado sin consultar el detalle', (
    tester,
  ) async {
    final harness = await _pumpHistory(tester);

    for (final path in ['/socio/historia/0', '/socio/historia/abc']) {
      harness.router.go(path);
      await _settle(tester);

      expect(_pathOf(tester), '/socio/historia', reason: path);
      expect(find.byType(MedicalHistoryScreen), findsOneWidget, reason: path);
      expect(
        find.byType(MedicalHistoryDetailScreen),
        findsNothing,
        reason: path,
      );
      expect(harness.repository.requestedIds, isEmpty, reason: path);
    }
  });

  testWidgets('la tarjeta 12 abre su ruta y solicita exactamente get(12)', (
    tester,
  ) async {
    final harness = await _pumpHistory(tester);

    expect(_pathOf(tester), '/socio/historia');
    expect(harness.repository.requestedIds, isEmpty);

    await _openDetail(tester, 12);

    expect(_pathOf(tester), '/socio/historia/12');
    expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
    expect(
      tester
          .widget<MedicalHistoryDetailScreen>(
            find.byType(MedicalHistoryDetailScreen),
          )
          .id,
      12,
    );
    expect(harness.repository.requestedIds, [12]);
    expect(find.text('Control cardiovascular'), findsOneWidget);
    expect(find.byKey(const Key('history-referral-7')), findsOneWidget);
    expect(find.byKey(const Key('history-referral-8')), findsOneWidget);
  });

  testWidgets('Atrás conserva reposo y las atenciones 12 y 11', (tester) async {
    final harness = await _pumpHistory(tester);

    await tester.enterText(
      find.byKey(const Key('medical-history-text')),
      'reposo',
    );
    final apply = find.widgetWithText(FilledButton, 'Aplicar filtros');
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await _settle(tester);

    expect(_card(12), findsOneWidget);
    expect(_card(11), findsOneWidget);
    expect(_card(10), findsNothing);
    expect(_card(13), findsNothing);

    await _openDetail(tester, 12);
    expect(_pathOf(tester), '/socio/historia/12');

    final back = find.descendant(
      of: find.byType(MedicalHistoryDetailScreen),
      matching: find.byType(BackButton),
    );
    expect(back, findsOneWidget);
    await tester.tap(back);
    await _settle(tester);

    expect(_pathOf(tester), '/socio/historia');
    expect(find.byType(MedicalHistoryScreen), findsOneWidget);
    expect(find.byType(MedicalHistoryDetailScreen), findsNothing);

    final search = tester.widget<TextFormField>(
      find.byKey(const Key('medical-history-text')),
    );
    expect(search.controller!.text, 'reposo');
    expect(
      harness.container.read(medicalHistoryFiltersProvider).text,
      'reposo',
    );
    expect(_card(12), findsOneWidget);
    expect(_card(11), findsOneWidget);
    expect(_card(10), findsNothing);
    expect(_card(13), findsNothing);
    expect(harness.repository.requestedIds, [12]);
  });

  testWidgets(
    'el acceso directo respeta sesión y rol sin consultar el detalle',
    (tester) async {
      final cases = <({SessionState session, String destination})>[
        (session: const SessionState(), destination: '/login'),
        for (final role in [
          UserRole.funcionario,
          UserRole.medico,
          UserRole.administrador,
        ])
          (
            session: SessionState(
              status: SessionStatus.authenticated,
              accessToken: 'prueba-otro-rol',
              role: role,
            ),
            destination: role.homePath,
          ),
      ];

      for (final testCase in cases) {
        final harness = _createHarness(testCase.session);

        try {
          late BuildContext parserContext;

          // Ejecuta el parser real sin montar pantallas de otros módulos.
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: harness.container,
              child: MaterialApp(
                home: Builder(
                  builder: (context) {
                    parserContext = context;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          );

          final matches = await harness.router.routeInformationParser
              .parseRouteInformationWithDependencies(
                RouteInformation(uri: Uri.parse('/socio/historia/12')),
                parserContext,
              );

          expect(
            matches.uri.path,
            testCase.destination,
            reason: 'Acceso desde ${testCase.session.role}',
          );
          expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
          expect(harness.repository.requestedIds, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.router.dispose();
          harness.container.dispose();
          await tester.pump(const Duration(milliseconds: 1));
        }
      }
    },
  );
}
