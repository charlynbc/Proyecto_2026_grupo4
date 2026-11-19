import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/home/screens/home_screen.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attention_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attention_detail_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attentions_screen.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'medico-atenciones-prueba',
    role: UserRole.medico,
  );
}

DoctorAttention _attention({
  int id = 7101,
  String date = '2026-11-16',
  String condition = 'Control inicial',
  String treatment = 'Reposo',
  String surname = 'Pérez',
  int specialtyId = 1,
}) => DoctorAttention.fromJson({
  'idAtencion': id,
  'fechaAtencion': date,
  'paciente': {
    'id': 18,
    'ci': '90000018',
    'nombre': 'Juan',
    'apellido': surname,
  },
  'especialidad': {
    'id': specialtyId,
    'nombre': 'Medicina General',
    'requierePase': false,
  },
  'afeccion': condition,
  'tratamiento': treatment,
  'observaciones': null,
  'pases': <dynamic>[],
});

class _MutableAttentions implements DoctorAttentionRepository {
  final entries = [_attention()];
  final queries = <DoctorAttentionQuery>[];
  final detailIds = <int>[];
  Future<List<DoctorAttention>> Function(DoctorAttentionQuery)? listResponse;

  void addAttention() {
    entries.add(
      _attention(
        id: 7102,
        date: '2026-11-17',
        condition: 'Control de seguimiento',
        treatment: 'Continuar tratamiento',
      ),
    );
  }

  void updateTreatment() {
    final index = entries.indexWhere((entry) => entry.id == 7101);
    entries[index] = _attention(treatment: 'Control en siete días');
  }

  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async {
    queries.add(query);
    final response = listResponse;
    if (response != null) return response(query);
    // Cada petición devuelve una copia: los cambios externos no deben mutar
    // la lista que el provider ya tiene guardada.
    final result = entries
        .where(
          (entry) =>
              !entry.attendedOn.isBefore(query.from) &&
              !entry.attendedOn.isAfter(query.to) &&
              (query.specialtyId == null ||
                  entry.specialty.id == query.specialtyId) &&
              (query.patientText.isEmpty ||
                  entry.patient.lastName.toLowerCase().contains(
                    query.patientText.toLowerCase(),
                  ) ||
                  entry.patient.ci.contains(
                    normalizePatientSearch(query.patientText),
                  )),
        )
        .toList();
    result.sort((a, b) {
      final comparison = query.order == DoctorAttentionOrder.date
          ? a.attendedOn.compareTo(b.attendedOn)
          : a.patient.lastName.compareTo(b.patient.lastName);
      return query.direction == DoctorAttentionDirection.ascending
          ? comparison
          : -comparison;
    });
    return result;
  }

  @override
  Future<DoctorAttention> get(int id) async {
    detailIds.add(id);
    return entries.singleWhere((entry) => entry.id == id);
  }

  int callsFor(int id) => detailIds.where((value) => value == id).length;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Finder _card(int id) => find.byKey(Key('attention-$id'));

Finder _detail(int id, {bool skipOffstage = true}) => find.byWidgetPredicate(
  (widget) => widget is DoctorAttentionDetailScreen && widget.id == id,
  skipOffstage: skipOffstage,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

Future<_MutableAttentions> _pumpAttentions(
  WidgetTester tester, {
  Size size = const Size(1100, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _MutableAttentions();
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_Session.new),
      doctorAttentionRepositoryProvider.overrideWith((ref) async => repository),
      specialtiesProvider.overrideWith(
        (ref) async => const [
          Specialty(id: 1, name: 'Medicina General', requiresReferral: false),
        ],
      ),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
    ],
  );
  final router = container.read(goRouterProvider)..go('/medico/atenciones');
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
  // Aplicar fechas desde la UI evita depender de DoctorAttentionQuery.initial
  // y del mes real, sin sustituir el provider de filtros.
  for (final field in [
    ('attentions-from', '01/11/2026'),
    ('attentions-to', '30/11/2026'),
  ]) {
    final input = find.descendant(
      of: find.byKey(Key(field.$1)),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, field.$2);
  }
  await _tap(tester, find.byKey(const Key('attentions-search')));
  expect(find.byType(DoctorAttentionsScreen), findsOneWidget);
  expect(_card(7101), findsOneWidget);
  expect(
    find.text('16/11/2026 · Medicina General · Control inicial'),
    findsOneWidget,
  );
  expect(_card(7102), findsNothing);
  expect(repository.queries, isNotEmpty);
  expect(repository.queries.last.from, DateTime.utc(2026, 11, 1));
  expect(repository.queries.last.to, DateTime.utc(2026, 11, 30));
  return repository;
}

Future<void> _openDetail(WidgetTester tester) async {
  await _tap(tester, _card(7101));
  expect(_detail(7101), findsOneWidget);
  expect(find.text('Reposo'), findsOneWidget);
  expect(find.text('Juan Pérez'), findsOneWidget);
}

Future<void> _closeDetail(WidgetTester tester) async {
  await _tap(
    tester,
    find.descendant(of: _detail(7101), matching: find.byType(BackButton)),
  );
  expect(find.byType(DoctorAttentionsScreen), findsOneWidget);
  expect(_detail(7101, skipOffstage: false), findsNothing);
}

void _expectNewAttention() {
  expect(_card(7102), findsOneWidget);
  expect(
    find.text('17/11/2026 · Medicina General · Control de seguimiento'),
    findsOneWidget,
  );
  expect(find.text('2 atenciones'), findsOneWidget);
}

const _loadError = 'No pudimos actualizar las atenciones de prueba.';

StatefulNavigationShellState _shell(WidgetTester tester) =>
    StatefulNavigationShell.of(
      tester.element(find.byType(DoctorAttentionsScreen)),
    );

Future<void> _section(
  WidgetTester tester,
  StatefulNavigationShellState shell,
  String slug,
) async {
  shell.goBranch(UserRole.medico.sections.indexWhere((s) => s.slug == slug));
  await _settle(tester);
}

Finder _dateInput(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(EditableText),
);

Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, find.byKey(Key(key)));
  await _tap(tester, find.text(label).last);
}

Future<void> _expectOnScreen(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _settle(tester);
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(320));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(1000));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('al regresar conserva filtros, fechas y orden de Atenciones', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    await tester.enterText(_dateInput('attentions-from'), '15/11/2026');
    await tester.enterText(_dateInput('attentions-to'), '20/11/2026');
    await tester.enterText(
      find.byKey(const Key('attentions-patient-field')),
      'Pérez',
    );
    await _select(tester, 'attentions-specialty', 'Medicina General');
    await _tap(tester, find.byKey(const Key('attentions-search')));
    await _tap(tester, find.byKey(const Key('attentions-direction')));
    expect(find.text('Ascendente'), findsOneWidget);
    expect(_card(7101), findsOneWidget);
    final shell = _shell(tester);
    await _section(tester, shell, 'inicio');
    repo.addAttention();
    repo.entries.addAll([
      _attention(id: 7103, date: '2026-11-14'),
      _attention(id: 7104, surname: 'Gómez'),
      _attention(id: 7105, specialtyId: 2),
    ]);
    final before = repo.queries.length;

    await _section(tester, shell, 'atenciones');

    expect(repo.queries.length, greaterThan(before));
    final query = repo.queries.last;
    expect(query.from, DateTime.utc(2026, 11, 15));
    expect(query.to, DateTime.utc(2026, 11, 20));
    expect(query.patientText, 'Pérez');
    expect(query.specialtyId, 1);
    expect(query.order, DoctorAttentionOrder.date);
    expect(query.direction, DoctorAttentionDirection.ascending);
    expect(
      tester
          .widget<EditableText>(_dateInput('attentions-from'))
          .controller
          .text,
      '15/11/2026',
    );
    expect(
      tester.widget<EditableText>(_dateInput('attentions-to')).controller.text,
      '20/11/2026',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('attentions-patient-field')))
          .controller!
          .text,
      'Pérez',
    );
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('attentions-specialty')),
          )
          .value,
      1,
    );
    expect(find.text('Ascendente'), findsOneWidget);
    _expectNewAttention();
    expect(_card(7103), findsNothing);
    expect(_card(7104), findsNothing);
    expect(_card(7105), findsNothing);
    expect(
      tester.getTopLeft(_card(7101)).dy,
      lessThan(tester.getTopLeft(_card(7102)).dy),
    );
  });

  testWidgets('el error al regresar a Atenciones permite Reintentar', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    final shell = _shell(tester);
    await _section(tester, shell, 'inicio');
    repo.addAttention();
    repo.listResponse = (_) async => throw const ApiException(_loadError);
    final before = repo.queries.length;

    await _section(tester, shell, 'atenciones');

    expect(repo.queries.length, before + 1);
    expect(find.text(_loadError), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reintentar'), findsOneWidget);
    repo.listResponse = null;
    await _tap(tester, find.byKey(const Key('attentions-retry')));

    expect(repo.queries.length, before + 2);
    expect(find.text(_loadError), findsNothing);
    _expectNewAttention();
  });

  testWidgets('Atenciones mantiene los datos visibles durante el refresh', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    await tester.ensureVisible(_card(7101));
    await _settle(tester);
    final shell = _shell(tester);
    await _section(tester, shell, 'inicio');
    final gate = Completer<List<DoctorAttention>>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete([]);
    });
    repo.listResponse = (_) => gate.future;
    final before = repo.queries.length;
    shell.goBranch(
      UserRole.medico.sections.indexWhere((s) => s.slug == 'atenciones'),
    );
    // No usar pumpAndSettle con una respuesta que todavía no se resolvió.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.queries.length, before + 1);
    expect(gate.isCompleted, isFalse);
    expect(_card(7101).hitTestable(), findsOneWidget);
    expect(_card(7102), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete([
      _attention(
        id: 7102,
        date: '2026-11-17',
        condition: 'Control de seguimiento',
      ),
      _attention(),
    ]);
    await _settle(tester);

    _expectNewAttention();
    expect(repo.queries.length, before + 1);
  });

  testWidgets('Atenciones realiza una petición por cada regreso probado', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    final shell = _shell(tester);
    await _section(tester, shell, 'inicio');
    final listBefore = repo.queries.length;
    final detailsBefore = repo.detailIds.length;
    repo.addAttention();
    await _section(tester, shell, 'atenciones');
    _expectNewAttention();
    expect(repo.queries.length, listBefore + 1);
    expect(repo.detailIds.length, detailsBefore);

    await _openDetail(tester);
    expect(repo.callsFor(7101), 1);
    expect(repo.queries.length, listBefore + 1);
    final router = GoRouter.of(tester.element(_detail(7101)));
    final cover = router.push<void>('/medico/atenciones/7102');
    await _settle(tester);
    expect(_detail(7102), findsOneWidget);
    expect(repo.callsFor(7102), 1);
    repo.updateTreatment();
    router.pop();
    await _settle(tester);
    await cover;
    expect(find.text('Control en siete días'), findsOneWidget);
    expect(repo.callsFor(7101), 2);
    expect(repo.callsFor(7102), 1);
    expect(repo.queries.length, listBefore + 1);

    await _closeDetail(tester);
    _expectNewAttention();
    expect(repo.queries.length, listBefore + 2);
    expect(repo.detailIds, [7101, 7102, 7101]);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.queries.length, listBefore + 2);
    expect(repo.detailIds, [7101, 7102, 7101]);
  });

  testWidgets(
    'a 320 px Atenciones muestra lista, detalle y error sin desbordes',
    (tester) async {
      final repo = await _pumpAttentions(tester, size: const Size(320, 1000));
      await _expectOnScreen(tester, _card(7101));
      final shell = _shell(tester);
      await _section(tester, shell, 'inicio');
      repo.addAttention();
      final before = repo.queries.length;
      await _section(tester, shell, 'atenciones');
      expect(repo.queries.length, greaterThan(before));
      _expectNewAttention();
      await _expectOnScreen(tester, _card(7102));
      await _openDetail(tester);
      expect(repo.callsFor(7101), greaterThan(0));
      await _expectOnScreen(tester, find.text('Juan Pérez'));
      await _expectOnScreen(tester, find.text('Reposo'));
      final beforeError = repo.queries.length;
      repo.listResponse = (_) async => throw const ApiException(_loadError);
      await _closeDetail(tester);
      expect(repo.queries.length, greaterThan(beforeError));
      await _expectOnScreen(tester, find.text(_loadError));
      await _expectOnScreen(tester, find.byKey(const Key('attentions-retry')));
    },
  );

  testWidgets(
    'el detalle actualizado conserva la pila y vuelve a la misma lista',
    (tester) async {
      final repo = await _pumpAttentions(tester);
      final listElement = tester.element(find.byType(DoctorAttentionsScreen));
      await _openDetail(tester);
      final detailElement = tester.element(_detail(7101));
      final router = GoRouter.of(detailElement);
      repo.addAttention();
      final cover = router.push<void>('/medico/atenciones/7102');
      await _settle(tester);
      expect(find.text('Continuar tratamiento'), findsOneWidget);
      expect(
        tester.element(_detail(7101, skipOffstage: false)),
        same(detailElement),
      );
      repo.updateTreatment();
      final before = repo.callsFor(7101);
      // Volver con el botón real de la segunda ruta raíz.
      await _tap(
        tester,
        find.descendant(of: _detail(7102), matching: find.byType(BackButton)),
      );
      await cover;

      expect(tester.element(_detail(7101)), same(detailElement));
      expect(find.text('Control en siete días'), findsOneWidget);
      expect(repo.callsFor(7101), greaterThan(before));
      expect(router.canPop(), isTrue);
      expect(_detail(7102, skipOffstage: false), findsNothing);
      final listBefore = repo.queries.length;
      await _closeDetail(tester);
      expect(
        tester.element(find.byType(DoctorAttentionsScreen)),
        same(listElement),
      );
      expect(repo.queries.length, greaterThan(listBefore));
      _expectNewAttention();
      expect(
        tester
            .widget<EditableText>(_dateInput('attentions-from'))
            .controller
            .text,
        '01/11/2026',
      );
      expect(
        tester
            .widget<EditableText>(_dateInput('attentions-to'))
            .controller
            .text,
        '30/11/2026',
      );
    },
  );

  testWidgets('Atenciones actualiza la lista al volver desde Inicio', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    final listElement = tester.element(find.byType(DoctorAttentionsScreen));
    final shell = StatefulNavigationShell.of(listElement);
    repo.addAttention();
    shell.goBranch(
      UserRole.medico.sections.indexWhere((s) => s.slug == 'inicio'),
    );
    await _settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(listElement.mounted, isTrue);
    final before = repo.queries.length;

    shell.goBranch(
      UserRole.medico.sections.indexWhere((s) => s.slug == 'atenciones'),
    );
    await _settle(tester);

    expect(
      tester.element(find.byType(DoctorAttentionsScreen)),
      same(listElement),
    );
    _expectNewAttention();
    expect(repo.queries.length, greaterThan(before));
  });

  testWidgets('Atenciones actualiza el detalle conservado al regresar', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    await _openDetail(tester);
    expect(repo.callsFor(7101), greaterThan(0));
    final detailElement = tester.element(_detail(7101));
    final router = GoRouter.of(detailElement);
    repo.addAttention();
    // Ambos detalles son rutas raíz reales. push conserva la primera debajo
    // de la segunda; go reemplazaría el recorrido y no probaría este caso.
    final coveringRoute = router.push<void>('/medico/atenciones/7102');
    await _settle(tester);
    expect(_detail(7102), findsOneWidget);
    expect(find.text('Continuar tratamiento'), findsOneWidget);
    expect(_detail(7101), findsNothing);
    expect(
      tester.element(_detail(7101, skipOffstage: false)),
      same(detailElement),
    );
    repo.updateTreatment();
    final before = repo.callsFor(7101);

    router.pop();
    await _settle(tester);
    await coveringRoute;

    expect(tester.element(_detail(7101)), same(detailElement));
    expect(find.text('Control en siete días'), findsOneWidget);
    expect(find.text('Reposo'), findsNothing);
    expect(repo.callsFor(7101), greaterThan(before));
  });

  testWidgets('Atenciones actualiza el detalle cerrado y reabierto', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    await _openDetail(tester);
    expect(repo.callsFor(7101), greaterThan(0));
    await _closeDetail(tester);
    repo.updateTreatment();
    final before = repo.callsFor(7101);

    await _tap(tester, _card(7101));

    expect(_detail(7101), findsOneWidget);
    expect(find.text('Control en siete días'), findsOneWidget);
    expect(find.text('Reposo'), findsNothing);
    expect(repo.callsFor(7101), greaterThan(before));
  });

  testWidgets('Atenciones actualiza la lista al volver desde el detalle', (
    tester,
  ) async {
    final repo = await _pumpAttentions(tester);
    final listElement = tester.element(find.byType(DoctorAttentionsScreen));
    await _openDetail(tester);
    expect(listElement.mounted, isTrue);
    repo.addAttention();
    final before = repo.queries.length;

    await _closeDetail(tester);

    expect(
      tester.element(find.byType(DoctorAttentionsScreen)),
      same(listElement),
    );
    _expectNewAttention();
    expect(repo.queries.length, greaterThan(before));
  });

  group('al volver la pestaña o la app a primer plano', () {
    testWidgets('Atenciones actualiza la lista con un solo pedido', (
      tester,
    ) async {
      final repo = await _pumpAttentions(tester);
      expect(_card(7101), findsOneWidget);
      expect(_card(7102), findsNothing);
      // Mientras la app estaba en segundo plano se registró la 7102
      // (17/11/2026, "Control de seguimiento").
      repo.addAttention();
      final before = repo.queries.length;

      backgroundAndReturn(tester);
      await _settle(tester);

      _expectNewAttention();
      expect(repo.queries.length, before + 1);
    });

    testWidgets('con Atenciones en otra sección no pide nada', (tester) async {
      final repo = await _pumpAttentions(tester);
      final shell = _shell(tester);
      await _section(tester, shell, 'inicio');
      repo.addAttention();
      final before = repo.queries.length;

      backgroundAndReturn(tester);
      await _settle(tester);

      expect(repo.queries.length, before);

      // Al volver a Atenciones lo hace el regreso a la sección, una sola vez.
      await _section(tester, shell, 'atenciones');
      _expectNewAttention();
      expect(repo.queries.length, before + 1);
    });

    testWidgets('sin pasar a segundo plano no hay pedidos extra', (
      tester,
    ) async {
      final repo = await _pumpAttentions(tester);
      repo.addAttention();
      final before = repo.queries.length;

      await _settle(tester);

      expect(repo.queries.length, before);
      expect(_card(7102), findsNothing);
    });

    testWidgets('con el detalle abierto lo actualiza al volver', (
      tester,
    ) async {
      final repo = await _pumpAttentions(tester);
      await _openDetail(tester);
      final before = repo.callsFor(7101);
      repo.updateTreatment();

      backgroundAndReturn(tester);
      await _settle(tester);

      expect(find.text('Control en siete días'), findsOneWidget);
      expect(find.text('Reposo'), findsNothing);
      expect(repo.callsFor(7101), before + 1);
    });
  });
}
