import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_filters_controller.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class _RecordingAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) async {
    throw StateError('Estos tests no deben iniciar sesión.');
  }

  @override
  Future<void> refresh() async {
    throw const AuthException();
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

Future<void> _settleLogout(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

class _TestSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'prueba-pantalla',
    role: UserRole.socio,
  );
}

/// Registra consultas y delega los resultados al fake propio de RF-12.
class _RecordingRepository implements MedicalHistoryRepository {
  final fake = FakeMedicalHistoryRepository(latency: Duration.zero);
  final List<MedicalHistoryQuery> queries = [];
  Future<List<MedicalHistoryEntry>> Function(MedicalHistoryQuery)? response;

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) {
    queries.add(query);
    final answer = response;
    return answer == null ? fake.list(query) : answer(query);
  }

  @override
  Future<MedicalHistoryEntry> get(int id) => fake.get(id);
}

Future<void> _pump(
  WidgetTester tester,
  _RecordingRepository repository, {
  Size size = const Size(1100, 900),
  bool settle = true,
  AuthRepository? auth,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_TestSession.new),
      medicalHistoryRepositoryProvider.overrideWith((ref) async => repository),
      if (auth != null)
        authRepositoryProvider.overrideWith((ref) async => auth),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appTheme,
        locale: const Locale('es', 'UY'),
        supportedLocales: const [Locale('es', 'UY')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const MedicalHistoryScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Finder _card(int id) => find.byKey(ValueKey('medical-history-entry-$id'));

void _expectCards(List<int> ids) {
  for (final id in [10, 11, 12, 13]) {
    expect(_card(id), ids.contains(id) ? findsOneWidget : findsNothing);
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, find.byKey(ValueKey(key)));
  // Flutter envuelve cada opción abierta en Semantics(menuItem) y coloca
  // dentro un InkWell si está habilitada. El botón cerrado no tiene ese rol.
  final menuItem = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.role == SemanticsRole.menuItem,
    ),
  );
  expect(menuItem, findsOneWidget, reason: 'Opción "$label" del selector $key');
  final item = find.descendant(
    of: menuItem,
    matching: find.byWidgetPredicate((widget) => widget is DropdownMenuItem),
  );
  final expectedValue = tester.widget<DropdownMenuItem<dynamic>>(item).value;
  final option = find
      .descendant(of: menuItem, matching: find.byType(InkWell))
      .hitTestable();
  expect(option, findsOneWidget);
  await tester.tap(option);
  // Procesa el pop y el inicio de la animación inversa antes de esperar reposo.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  expect(
    menuItem,
    findsNothing,
    reason: 'La opción elegida debe cerrar su menú',
  );
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField,
    ),
  );
  expect(
    tester.state<FormFieldState<dynamic>>(field).value,
    expectedValue,
    reason: 'El selector $key debe conservar el valor de "$label"',
  );
  expect(
    find
        .descendant(of: find.byKey(ValueKey(key)), matching: find.text(label))
        .hitTestable(),
    findsOneWidget,
    reason: 'El selector $key debe mostrar la selección "$label"',
  );
}

Future<void> _apply(WidgetTester tester) =>
    _tap(tester, find.widgetWithText(FilledButton, 'Aplicar filtros'));

void main() {
  testWidgets(
    'muestra las cuatro atenciones con sus datos y fecha descendente',
    (tester) async {
      await _pump(tester, _RecordingRepository());

      _expectCards([12, 10, 11, 13]);
      const expected = {
        12: [
          '02/10/2026',
          'Diego Viera',
          'Cardiología',
          'Control cardiovascular',
        ],
        10: ['24/09/2026', 'Diego Viera', 'Cardiología', 'gripe'],
        11: ['10/09/2026', 'Laura Pérez', 'Traumatología', 'Dolor lumbar'],
        13: [
          '20/08/2026',
          'Ana Silva',
          'Dermatología',
          'Reposo mencionado en afección',
        ],
      };
      for (final entry in expected.entries) {
        for (final text in entry.value) {
          expect(
            find.descendant(
              of: _card(entry.key),
              matching: find.textContaining(text),
            ),
            findsOneWidget,
          );
        }
      }
      expect(
        tester.getTopLeft(_card(12)).dy,
        lessThan(tester.getTopLeft(_card(10)).dy),
      );
      expect(
        tester.getTopLeft(_card(10)).dy,
        lessThan(tester.getTopLeft(_card(11)).dy),
      );
      expect(
        tester.getTopLeft(_card(11)).dy,
        lessThan(tester.getTopLeft(_card(13)).dy),
      );
    },
  );

  testWidgets('aplica rango de fechas inclusivo', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);

    await tester.enterText(
      find.byKey(const Key('medical-history-from')),
      '10/09/2026',
    );
    await tester.enterText(
      find.byKey(const Key('medical-history-to')),
      '24/09/2026',
    );
    await _apply(tester);

    expect(repository.queries.last.from, DateTime.utc(2026, 9, 10));
    expect(repository.queries.last.to, DateTime.utc(2026, 9, 24));
    _expectCards([10, 11]);
  });

  testWidgets('filtra por especialidad usando el ID propio del fake', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);

    await _select(tester, 'medical-history-specialty', 'Traumatología');
    await _apply(tester);

    expect(repository.queries.last.specialtyId, 5);
    _expectCards([11]);
  });

  testWidgets('filtra por médico elegido por nombre', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);

    await _select(tester, 'medical-history-doctor', 'Diego Viera');
    await _apply(tester);

    expect(repository.queries.last.doctorId, 4);
    _expectCards([12, 10]);
  });

  testWidgets('busca texto exclusivamente en el tratamiento', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);

    await tester.enterText(
      find.byKey(const Key('medical-history-text')),
      'reposo',
    );
    await _apply(tester);

    expect(repository.queries.last.text, 'reposo');
    _expectCards([12, 11]);
  });

  testWidgets(
    'cambia el orden y limpiar restaura filtros y fecha descendente',
    (tester) async {
      final repository = _RecordingRepository();
      await _pump(tester, repository);
      await _select(tester, 'medical-history-specialty', 'Cardiología');
      await _select(tester, 'medical-history-doctor', 'Diego Viera');
      await tester.enterText(
        find.byKey(const Key('medical-history-from')),
        '01/09/2026',
      );
      await tester.enterText(
        find.byKey(const Key('medical-history-to')),
        '02/10/2026',
      );
      await tester.enterText(
        find.byKey(const Key('medical-history-text')),
        'reposo',
      );
      await _apply(tester);
      _expectCards([12]);

      await _select(tester, 'medical-history-order', 'Especialidad');
      await _select(tester, 'medical-history-direction', 'Ascendente');
      await _apply(tester);

      expect(repository.queries.last.order, MedicalHistoryOrder.specialty);
      expect(
        repository.queries.last.direction,
        MedicalHistoryDirection.ascending,
      );
      expect(repository.queries.last.specialtyId, 3);
      expect(repository.queries.last.text, 'reposo');

      await _tap(tester, find.widgetWithText(OutlinedButton, 'Limpiar'));

      final query = repository.queries.last;
      expect(query.from, isNull);
      expect(query.to, isNull);
      expect(query.specialtyId, isNull);
      expect(query.doctorId, isNull);
      expect(query.text ?? '', isEmpty);
      expect(query.order, MedicalHistoryOrder.date);
      expect(query.direction, MedicalHistoryDirection.descending);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('medical-history-text')),
            )
            .controller!
            .text,
        isEmpty,
      );
      _expectCards([12, 10, 11, 13]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MedicalHistoryScreen)),
      );
      final applied = container.read(medicalHistoryFiltersProvider);
      expect(applied.from, isNull);
      expect(applied.to, isNull);
      expect(applied.specialtyId, isNull);
      expect(applied.doctorId, isNull);
      expect(applied.text, isNull);
      expect(applied.order, MedicalHistoryOrder.date);
      expect(applied.direction, MedicalHistoryDirection.descending);

      for (final entry in const {
        'medical-history-specialty': 'Todas',
        'medical-history-doctor': 'Todos',
        'medical-history-order': 'Fecha',
        'medical-history-direction': 'Descendente',
      }.entries) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(entry.key)),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester
            .state<FormFieldState<int>>(
              find.descendant(
                of: find.byKey(const Key('medical-history-specialty')),
                matching: find.byType(DropdownButtonFormField<int>),
              ),
            )
            .value,
        isNull,
      );
      expect(
        tester
            .state<FormFieldState<int>>(
              find.descendant(
                of: find.byKey(const Key('medical-history-doctor')),
                matching: find.byType(DropdownButtonFormField<int>),
              ),
            )
            .value,
        isNull,
      );
    },
  );

  testWidgets('rango invertido muestra validación y no consulta de nuevo', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    final initialCalls = repository.queries.length;

    await tester.enterText(
      find.byKey(const Key('medical-history-from')),
      '02/10/2026',
    );
    await tester.enterText(
      find.byKey(const Key('medical-history-to')),
      '01/09/2026',
    );
    await _apply(tester);

    expect(
      find.text('La fecha "Desde" no puede ser posterior a la fecha "Hasta".'),
      findsOneWidget,
    );
    expect(repository.queries, hasLength(initialCalls));
    _expectCards([12, 10, 11, 13]);
  });

  testWidgets('muestra carga mientras las atenciones están pendientes', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    final pending = Completer<List<MedicalHistoryEntry>>();
    repository.response = (_) => pending.future;
    await _pump(tester, repository, settle: false);

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    _expectCards([]);

    // pump() sin duración solo procesa microtareas: no ejecuta el timer de
    // Future.delayed(Duration.zero). Hay que avanzar explícitamente el reloj.
    final entriesFuture = repository.fake.list(const MedicalHistoryQuery());
    await tester.pump(const Duration(milliseconds: 1));
    final entries = await entriesFuture;
    pending.complete(entries);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    _expectCards([12, 10, 11, 13]);
  });

  testWidgets('muestra error de carga y permite reintentar', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    repository.response = (query) async {
      if (query.text == 'reposo') {
        throw const ApiException('No pudimos cargar las atenciones de prueba.');
      }
      return repository.fake.list(query);
    };
    await tester.enterText(
      find.byKey(const Key('medical-history-text')),
      'reposo',
    );
    await _apply(tester);

    expect(
      find.text('No pudimos cargar las atenciones de prueba.'),
      findsOneWidget,
    );
    final failedCalls = repository.queries.length;
    repository.response = null;
    await _tap(tester, find.text('Reintentar').last);

    expect(repository.queries.length, greaterThan(failedCalls));
    _expectCards([12, 11]);
    expect(
      find.text('No pudimos cargar las atenciones de prueba.'),
      findsNothing,
    );
  });

  testWidgets('muestra un mensaje cuando la lista está vacía', (tester) async {
    final repository = _RecordingRepository();
    repository.response = (_) async => <MedicalHistoryEntry>[];
    await _pump(tester, repository);

    _expectCards([]);
    expect(find.textContaining('No hay atenciones'), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets(
      'controles accesibles sin desbordes en ${size.width.toInt()} px',
      (tester) async {
        await _pump(tester, _RecordingRepository(), size: size);

        expect(tester.takeException(), isNull);
        for (final key in [
          'medical-history-from',
          'medical-history-to',
          'medical-history-specialty',
          'medical-history-doctor',
          'medical-history-text',
          'medical-history-order',
          'medical-history-direction',
        ]) {
          final control = find.byKey(ValueKey(key));
          expect(control, findsOneWidget);
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          expect(control.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(_card(13));
        await tester.pumpAndSettle();
        expect(_card(13).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  group('RF-03', () {
    setUpAll(loadRoboto);

    testWidgets('muestra un único LogoutButton y tooltip Cerrar sesión', (
      tester,
    ) async {
      final auth = _RecordingAuthRepository();
      await _pump(tester, _RecordingRepository(), auth: auth);

      expect(find.byType(MedicalHistoryScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      expect(auth.logoutCalls, 0);
    });

    testWidgets('ubica LogoutButton en el AppBar y conserva el título', (
      tester,
    ) async {
      await _pump(
        tester,
        _RecordingRepository(),
        auth: _RecordingAuthRepository(),
      );

      expect(find.byType(MedicalHistoryScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);
      expect(
        find.descendant(of: appBar, matching: find.byType(LogoutButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appBar, matching: find.text('Mi historia clínica')),
        findsOneWidget,
      );
    });

    testWidgets('Cancelar cierra el diálogo sin llamar a logout', (
      tester,
    ) async {
      final auth = _RecordingAuthRepository();
      await _pump(tester, _RecordingRepository(), auth: auth);

      expect(find.byType(MedicalHistoryScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      final logout = find.byTooltip('Cerrar sesión');
      expect(logout, findsOneWidget);
      expect(auth.logoutCalls, 0);
      await tester.tap(logout);
      await _settleLogout(tester);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('¿Confirmás que querés cerrar la sesión?'),
        ),
        findsOneWidget,
      );
      final cancel = find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Cancelar'),
      );
      final confirm = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Cerrar sesión'),
      );
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(auth.logoutCalls, 0);

      await tester.tap(cancel);
      await _settleLogout(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(MedicalHistoryScreen), findsOneWidget);
      expect(auth.logoutCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Confirmar llama a logout exactamente una vez', (tester) async {
      final auth = _RecordingAuthRepository();
      await _pump(tester, _RecordingRepository(), auth: auth);

      expect(find.byType(MedicalHistoryScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      final logout = find.byTooltip('Cerrar sesión');
      expect(logout, findsOneWidget);
      await tester.tap(logout);
      await _settleLogout(tester);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final confirm = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Cerrar sesión'),
      );
      expect(confirm, findsOneWidget);
      expect(auth.logoutCalls, 0);
      await tester.tap(confirm);
      await _settleLogout(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.logoutCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a 320 px con Roboto muestra título y ambos accesos sin desbordes',
      (tester) async {
        await _pump(
          tester,
          _RecordingRepository(),
          auth: _RecordingAuthRepository(),
          size: const Size(320, 800),
        );

        expect(find.byType(MedicalHistoryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byType(LogoutButton), findsOneWidget);
        final logout = find.byTooltip('Cerrar sesión');
        final account = find.byTooltip('Mi cuenta');
        expect(logout, findsOneWidget);
        expect(account, findsOneWidget);
        expect(logout.hitTestable(), findsOneWidget);
        expect(account.hitTestable(), findsOneWidget);
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Mi historia clínica'),
        );
        expect(title, findsOneWidget);
        expect(title.hitTestable(), findsOneWidget);
        expect(tester.view.physicalSize, const Size(320, 800));
        expect(tester.view.devicePixelRatio, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
