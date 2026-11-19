import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_detail_screen.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_screen.dart';
import 'package:agenda_medica/features/home/screens/home_screen.dart';
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
    accessToken: 'socio-historia-prueba',
    role: UserRole.socio,
  );
}

MedicalHistoryEntry _entry({
  int id = 7101,
  String date = '2026-11-16',
  String condition = 'Control inicial',
  String treatment = 'Reposo',
  int doctorId = 41,
  String doctorName = 'Beatriz',
  String doctorSurname = 'Cabrera',
}) => MedicalHistoryEntry.fromJson({
  'idAtencion': id,
  'fechaAtencion': date,
  'medicoId': doctorId,
  'medicoNombre': doctorName,
  'medicoApellido': doctorSurname,
  'especialidad': {
    'id': 1,
    'nombre': 'Medicina General',
    'requierePase': false,
  },
  'afeccion': condition,
  'tratamiento': treatment,
  'observaciones': null,
  'pases': <dynamic>[],
});

class _MutableHistory implements MedicalHistoryRepository {
  final entries = [_entry()];
  int listCalls = 0;
  final detailIds = <int>[];
  final queries = <MedicalHistoryQuery>[];
  Future<List<MedicalHistoryEntry>> Function(MedicalHistoryQuery)? listResponse;

  void addAttention() {
    entries.insert(
      0,
      _entry(
        id: 7102,
        date: '2026-11-17',
        condition: 'Control de seguimiento',
        treatment: 'Control en siete días',
      ),
    );
  }

  void updateTreatment() {
    entries[0] = _entry(treatment: 'Control en siete días');
  }

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) async {
    listCalls++;
    queries.add(query);
    final response = listResponse;
    if (response != null) return response(query);
    // Una copia evita que mutar el repositorio modifique el resultado cacheado.
    final result = entries.where((entry) {
      return (query.from == null || !entry.attendedOn.isBefore(query.from!)) &&
          (query.to == null || !entry.attendedOn.isAfter(query.to!)) &&
          (query.doctorId == null || entry.doctorId == query.doctorId) &&
          (query.specialtyId == null ||
              entry.specialty.id == query.specialtyId) &&
          (query.text == null ||
              (entry.treatment ?? '').toLowerCase().contains(
                query.text!.toLowerCase(),
              ));
    }).toList();
    result.sort((a, b) {
      final comparison = query.order == MedicalHistoryOrder.date
          ? a.attendedOn.compareTo(b.attendedOn)
          : a.specialty.name.compareTo(b.specialty.name);
      return query.direction == MedicalHistoryDirection.ascending
          ? comparison
          : -comparison;
    });
    return result;
  }

  @override
  Future<MedicalHistoryEntry> get(int id) async {
    detailIds.add(id);
    return entries.singleWhere((entry) => entry.id == id);
  }
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<_MutableHistory> _pumpHistory(
  WidgetTester tester, {
  Size size = const Size(1100, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _MutableHistory();
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_Session.new),
      medicalHistoryRepositoryProvider.overrideWith((ref) async => repository),
      // Inicio no necesita cargar imágenes ni mantener un carrusel para probar
      // la navegación entre ramas del shell.
      latestAnnouncementsProvider.overrideWith((ref) async => []),
    ],
  );
  final router = container.read(goRouterProvider)..go('/socio/historia');
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
  expect(find.byType(MedicalHistoryScreen), findsOneWidget);
  expect(_card(7101), findsOneWidget);
  expect(_card(7102), findsNothing);
  expect(repository.listCalls, greaterThan(0));
  return repository;
}

Finder _card(int id) => find.byKey(ValueKey('medical-history-entry-$id'));

Future<void> _openDetail(WidgetTester tester) async {
  final button = find.descendant(
    of: _card(7101),
    matching: find.widgetWithText(OutlinedButton, 'Ver detalle'),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _settle(tester);
  expect(find.byType(MedicalHistoryDetailScreen), findsOneWidget);
}

Future<void> _backToList(WidgetTester tester) async {
  final back = find.descendant(
    of: find.byType(MedicalHistoryDetailScreen),
    matching: find.byType(BackButton),
  );
  await tester.tap(back);
  await _settle(tester);
  expect(find.byType(MedicalHistoryScreen), findsOneWidget);
  expect(find.byType(MedicalHistoryDetailScreen), findsNothing);
}

Future<void> _switchSection(
  WidgetTester tester,
  StatefulNavigationShellState shell,
  String slug,
) async {
  final index = UserRole.socio.sections.indexWhere((s) => s.slug == slug);
  expect(index, greaterThanOrEqualTo(0));
  // goBranch conserva la pila de cada sección, igual que la navegación del shell.
  shell.goBranch(index);
  await _settle(tester);
}

void _expectNewAttention(WidgetTester tester) {
  expect(_card(7102), findsOneWidget);
  expect(
    find.descendant(of: _card(7102), matching: find.text('17/11/2026')),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: _card(7102),
      matching: find.text('Control de seguimiento'),
    ),
    findsOneWidget,
  );
}

StatefulNavigationShellState _shell(WidgetTester tester) =>
    StatefulNavigationShell.of(
      tester.element(find.byType(MedicalHistoryScreen)),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, find.byKey(Key(key)));
  await _tap(tester, find.text(label).last);
}

Future<void> _applyReposo(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('medical-history-text')),
    'Reposo',
  );
  await _tap(tester, find.widgetWithText(FilledButton, 'Aplicar filtros'));
}

Future<void> _pendingFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('al regresar conserva filtros aplicados y orden ascendente', (
    tester,
  ) async {
    final repo = await _pumpHistory(tester);
    await _select(tester, 'medical-history-doctor', 'Beatriz Cabrera');
    await _applyReposo(tester);
    await _tap(tester, find.byKey(const Key('medical-history-direction')));
    final shell = _shell(tester);
    await _switchSection(tester, shell, 'inicio');
    repo.entries.add(
      _entry(
        id: 7102,
        date: '2026-11-17',
        condition: 'Seguimiento con reposo',
        treatment: 'Reposo adicional',
      ),
    );
    repo.entries.add(_entry(id: 7103, treatment: 'Control sin medicación'));
    final before = repo.queries.length;

    await _switchSection(tester, shell, 'historia');

    final requests = repo.queries.skip(before).where((q) => q.text == 'Reposo');
    expect(requests, hasLength(1));
    expect(requests.single.doctorId, 41);
    expect(requests.single.order, MedicalHistoryOrder.date);
    expect(requests.single.direction, MedicalHistoryDirection.ascending);
    expect(find.text('Ascendente'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('medical-history-text')))
          .controller!
          .text,
      'Reposo',
    );
    expect(_card(7101), findsOneWidget);
    expect(_card(7102), findsOneWidget);
    expect(_card(7103), findsNothing);
    expect(
      tester.getTopLeft(_card(7101)).dy,
      lessThan(tester.getTopLeft(_card(7102)).dy),
    );
  });

  testWidgets('al regresar renueva médicos sin borrar el médico seleccionado', (
    tester,
  ) async {
    final repo = await _pumpHistory(tester);
    await _select(tester, 'medical-history-doctor', 'Beatriz Cabrera');
    await _tap(tester, find.widgetWithText(FilledButton, 'Aplicar filtros'));
    final shell = _shell(tester);
    await _switchSection(tester, shell, 'inicio');
    repo.entries.add(
      _entry(
        id: 7102,
        doctorId: 42,
        doctorName: 'Laura',
        doctorSurname: 'Pérez',
      ),
    );
    final before = repo.queries.length;

    await _switchSection(tester, shell, 'historia');

    final requests = repo.queries.skip(before).toList();
    expect(requests.where((q) => q.doctorId == null), hasLength(1));
    expect(requests.where((q) => q.doctorId == 41), hasLength(1));
    final selector = find.descendant(
      of: find.byKey(const Key('medical-history-doctor')),
      matching: find.byType(DropdownButtonFormField<int>),
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(selector).initialValue,
      41,
    );
    expect(_card(7102), findsNothing);
    await _tap(tester, find.byKey(const Key('medical-history-doctor')));
    expect(find.text('Laura Pérez'), findsOneWidget);
    await _tap(tester, find.text('Laura Pérez'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Aplicar filtros'));
    expect(repo.queries.last.doctorId, 42);
    expect(_card(7102), findsOneWidget);
    expect(_card(7101), findsNothing);
  });

  testWidgets(
    'el error al regresar permite Reintentar y recuperar datos nuevos',
    (tester) async {
      final repo = await _pumpHistory(tester);
      await _applyReposo(tester);
      final shell = _shell(tester);
      await _switchSection(tester, shell, 'inicio');
      repo.listResponse = (query) async {
        if (query.text == 'Reposo') {
          throw const ApiException(
            'No pudimos actualizar la historia de prueba.',
          );
        }
        return List.of(repo.entries);
      };
      final before = repo.queries.where((q) => q.text == 'Reposo').length;
      await _switchSection(tester, shell, 'historia');
      expect(
        find.text('No pudimos actualizar la historia de prueba.'),
        findsOneWidget,
      );
      expect(
        repo.queries.where((q) => q.text == 'Reposo'),
        hasLength(before + 1),
      );
      repo.listResponse = null;
      repo.entries.add(
        _entry(id: 7102, condition: 'Recuperada', treatment: 'Reposo'),
      );

      await _tap(tester, find.widgetWithText(OutlinedButton, 'Reintentar'));

      expect(
        repo.queries.where((q) => q.text == 'Reposo'),
        hasLength(before + 2),
      );
      expect(
        find.text('No pudimos actualizar la historia de prueba.'),
        findsNothing,
      );
      expect(_card(7102), findsOneWidget);
      expect(find.text('Recuperada'), findsOneWidget);
    },
  );

  testWidgets('al regresar mantiene los datos visibles durante la petición', (
    tester,
  ) async {
    final repo = await _pumpHistory(tester);
    await _applyReposo(tester);
    final shell = _shell(tester);
    await _switchSection(tester, shell, 'inicio');
    final pending = Completer<List<MedicalHistoryEntry>>();
    repo.listResponse = (q) => q.text == 'Reposo'
        ? pending.future
        : Future.value(List.of(repo.entries));
    final before = repo.queries.where((q) => q.text == 'Reposo').length;
    shell.goBranch(
      UserRole.socio.sections.indexWhere((s) => s.slug == 'historia'),
    );
    await _pendingFrames(tester);

    expect(
      repo.queries.where((q) => q.text == 'Reposo'),
      hasLength(before + 1),
    );
    expect(_card(7101), findsOneWidget);
    expect(_card(7102), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    pending.complete([
      _entry(id: 7102, date: '2026-11-17', condition: 'Respuesta nueva'),
    ]);
    await _settle(tester);
    expect(_card(7101), findsNothing);
    expect(_card(7102), findsOneWidget);
    expect(find.text('Respuesta nueva'), findsOneWidget);
  });

  testWidgets('cada regreso pide una lista filtrada y una lista de opciones', (
    tester,
  ) async {
    final repo = await _pumpHistory(tester);
    await _applyReposo(tester);
    final shell = _shell(tester);
    for (var visit = 0; visit < 2; visit++) {
      final beforeLeaving = repo.queries.length;
      await _switchSection(tester, shell, 'inicio');
      expect(repo.queries.length, beforeLeaving);
      await _switchSection(tester, shell, 'historia');
      final requests = repo.queries.skip(beforeLeaving).toList();
      expect(requests, hasLength(2));
      expect(requests.where((q) => q.text == 'Reposo'), hasLength(1));
      expect(requests.where((q) => q.text == null), hasLength(1));
      expect(_card(7101), findsOneWidget);
      await _pendingFrames(tester);
      expect(repo.queries.length, beforeLeaving + 2);
    }
  });

  testWidgets(
    'cambiar de socio descarta la respuesta pendiente de la sesión A',
    (tester) async {
      final repo = await _pumpHistory(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MedicalHistoryScreen)),
        listen: false,
      );
      final shell = _shell(tester);
      await _switchSection(tester, shell, 'inicio');
      final oldResponse = Completer<List<MedicalHistoryEntry>>();
      repo.listResponse = (_) => oldResponse.future;
      final beforeA = repo.listCalls;
      shell.goBranch(
        UserRole.socio.sections.indexWhere((s) => s.slug == 'historia'),
      );
      await _pendingFrames(tester);
      expect(repo.listCalls, greaterThan(beforeA));
      expect(_card(7101), findsOneWidget);

      final newResponse = Completer<List<MedicalHistoryEntry>>();
      repo.listResponse = (_) => newResponse.future;
      final beforeB = repo.listCalls;
      container
          .read(sessionProvider.notifier)
          .setAuthenticated(
            accessToken: 'socio-b-prueba',
            role: UserRole.socio,
          );
      // Se comprueba desde el primer frame de la nueva sesión.
      await tester.pump();
      expect(_card(7101), findsNothing);
      expect(find.text('Control inicial'), findsNothing);
      await _pendingFrames(tester);
      expect(repo.listCalls, greaterThan(beforeB));
      expect(_card(7101), findsNothing);
      expect(newResponse.isCompleted, isFalse);
      // El contenido principal tiene el Form de filtros y, al final, el
      // resultado del listado. Acotar este último excluye los indicadores
      // y errores de las opciones que están dentro del Form.
      final content = find.descendant(
        of: find.byType(MedicalHistoryScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Column && widget.children.any((child) => child is Form),
        ),
      );
      expect(content, findsOneWidget);
      final listBlock = find.byWidget(
        tester.widget<Column>(content).children.last,
      );
      expect(listBlock, findsOneWidget);
      expect(
        find.descendant(
          of: listBlock,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: listBlock,
          matching: find.text(
            'La sesión cambió. Estamos actualizando la consulta.',
          ),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: listBlock,
          matching: find.widgetWithText(OutlinedButton, 'Reintentar'),
        ),
        findsNothing,
      );
      expect(find.text('Control inicial'), findsNothing);
      newResponse.complete([
        _entry(
          id: 7201,
          condition: 'Atención del socio B',
          doctorName: 'Laura',
        ),
      ]);
      await _settle(tester);
      expect(_card(7201), findsOneWidget);
      expect(_card(7101), findsNothing);
      oldResponse.complete([
        _entry(),
        _entry(id: 7199, condition: 'Respuesta tardía A'),
      ]);
      await _pendingFrames(tester);
      expect(_card(7201), findsOneWidget);
      expect(_card(7101), findsNothing);
      expect(_card(7199), findsNothing);
      expect(find.text('Respuesta tardía A'), findsNothing);
    },
  );

  testWidgets('a 320 px el regreso, el detalle y el error no desbordan', (
    tester,
  ) async {
    final repo = await _pumpHistory(tester, size: const Size(320, 640));
    final shell = _shell(tester);
    await _switchSection(tester, shell, 'inicio');
    repo.addAttention();
    final before = repo.listCalls;
    await _switchSection(tester, shell, 'historia');
    _expectNewAttention(tester);
    expect(repo.listCalls, greaterThan(before));
    await tester.ensureVisible(_card(7102));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _openDetail(tester);
    expect(find.text('Reposo'), findsOneWidget);
    expect(repo.detailIds, [7101]);
    expect(tester.takeException(), isNull);
    await _backToList(tester);
    await _applyReposo(tester);
    await _switchSection(tester, shell, 'inicio');
    repo.listResponse = (q) async {
      if (q.text == 'Reposo') {
        throw const ApiException('Error de prueba a 320 px.');
      }
      return List.of(repo.entries);
    };
    final beforeError = repo.queries.where((q) => q.text == 'Reposo').length;
    await _switchSection(tester, shell, 'historia');
    expect(
      repo.queries.where((q) => q.text == 'Reposo'),
      hasLength(beforeError + 1),
    );
    expect(find.text('Error de prueba a 320 px.'), findsOneWidget);
    await tester.ensureVisible(find.text('Reintentar'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Historia clínica actualiza la lista al volver desde Inicio', (
    tester,
  ) async {
    final repository = await _pumpHistory(tester);
    final element = tester.element(find.byType(MedicalHistoryScreen));
    final shell = StatefulNavigationShell.of(element);
    repository.addAttention();
    await _switchSection(tester, shell, 'inicio');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(element.mounted, isTrue);
    final callsBeforeReturn = repository.listCalls;

    await _switchSection(tester, shell, 'historia');

    expect(tester.element(find.byType(MedicalHistoryScreen)), same(element));
    _expectNewAttention(tester);
    // La lista y las opciones comparten list; no se fija un total artificial.
    expect(repository.listCalls, greaterThan(callsBeforeReturn));
  });

  testWidgets(
    'Historia clínica actualiza el tratamiento al reabrir el detalle',
    (tester) async {
      final repository = await _pumpHistory(tester);
      await _openDetail(tester);
      expect(find.text('Reposo'), findsOneWidget);
      expect(repository.detailIds, [7101]);
      await _backToList(tester);
      repository.updateTreatment();

      await _openDetail(tester);

      expect(find.text('Control en siete días'), findsOneWidget);
      expect(find.text('Reposo'), findsNothing);
      expect(repository.detailIds, [7101, 7101]);
    },
  );

  testWidgets('Historia clínica actualiza el detalle conservado al regresar', (
    tester,
  ) async {
    final repository = await _pumpHistory(tester);
    await _openDetail(tester);
    expect(find.text('Reposo'), findsOneWidget);
    expect(repository.detailIds, [7101]);
    final element = tester.element(find.byType(MedicalHistoryDetailScreen));
    final shell = StatefulNavigationShell.of(element);
    await _switchSection(tester, shell, 'inicio');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(element.mounted, isTrue);
    repository.updateTreatment();

    await _switchSection(tester, shell, 'historia');

    expect(
      tester.element(find.byType(MedicalHistoryDetailScreen)),
      same(element),
    );
    expect(find.text('Control en siete días'), findsOneWidget);
    expect(find.text('Reposo'), findsNothing);
    expect(repository.detailIds, [7101, 7101]);
  });

  testWidgets(
    'Historia clínica actualiza la lista al volver desde el detalle',
    (tester) async {
      final repository = await _pumpHistory(tester);
      await _openDetail(tester);
      repository.addAttention();
      final callsBeforeReturn = repository.listCalls;

      await _backToList(tester);

      _expectNewAttention(tester);
      expect(repository.listCalls, greaterThan(callsBeforeReturn));
    },
  );

  group('al volver la pestaña o la app a primer plano', () {
    testWidgets('actualiza la lista y las opciones con un pedido cada una', (
      tester,
    ) async {
      final repo = await _pumpHistory(tester);
      expect(_card(7101), findsOneWidget);
      expect(_card(7102), findsNothing);
      // Mientras la app estaba en segundo plano, el médico registró la 7102
      // (17/11/2026, "Control de seguimiento").
      repo.addAttention();
      final before = repo.queries.length;

      backgroundAndReturn(tester);
      await _settle(tester);

      _expectNewAttention(tester);
      // Un pedido de la lista y otro de las opciones.
      expect(repo.queries.length, before + 2);
    });

    testWidgets('con Historia en otra sección no pide nada', (tester) async {
      final repo = await _pumpHistory(tester);
      final shell = _shell(tester);
      await _switchSection(tester, shell, 'inicio');
      repo.addAttention();
      final before = repo.queries.length;

      backgroundAndReturn(tester);
      await _settle(tester);

      expect(repo.queries.length, before);

      // Al volver a Historia lo hace el regreso a la sección, una sola vez.
      await _switchSection(tester, shell, 'historia');
      _expectNewAttention(tester);
      expect(repo.queries.length, before + 2);
    });

    testWidgets('sin pasar a segundo plano no hay pedidos extra', (
      tester,
    ) async {
      final repo = await _pumpHistory(tester);
      repo.addAttention();
      final before = repo.queries.length;

      await _pendingFrames(tester);
      await _settle(tester);

      expect(repo.queries.length, before);
      expect(_card(7102), findsNothing);
    });

    testWidgets('con el detalle abierto lo actualiza al volver', (
      tester,
    ) async {
      final repo = await _pumpHistory(tester);
      await _openDetail(tester);
      expect(repo.detailIds, [7101]);
      expect(find.text('Reposo'), findsOneWidget);
      repo.updateTreatment();

      backgroundAndReturn(tester);
      await _settle(tester);

      expect(find.text('Control en siete días'), findsOneWidget);
      expect(find.text('Reposo'), findsNothing);
      expect(repo.detailIds, [7101, 7101]);
    });
  });
}
