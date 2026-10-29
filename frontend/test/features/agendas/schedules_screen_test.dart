import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/widgets/centered_content.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:agenda_medica/features/agendas/screens/schedules_screen.dart';
import 'package:agenda_medica/features/agendas/widgets/schedule_filter_bar.dart';
import 'package:agenda_medica/features/agendas/widgets/schedule_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import 'schedule_test_support.dart';

/// El mensaje que la pantalla muestra ante cualquier error que no sea una
/// validación del servidor.
const String _genericLoadError =
    'No pudimos cargar las consultas. Intentá de nuevo.';

/// Los cinco socios de las consultas de prueba.
const List<String> _members = [
  'Ana Fernández',
  'Carlos Rodríguez',
  'Luis Martínez',
  'Laura Gómez',
  'Pablo Sosa',
];

/// Corre el test y al final desmonta la pantalla, para que el temporizador del
/// refresco no quede pendiente.
void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}

/// Monta la pantalla con un router mínimo que además tiene otra ruta para
/// poder salir de ella.
Future<GoRouter> _pump(
  WidgetTester tester,
  RecordingScheduleRepository repository, {
  Duration? pollInterval = const Duration(hours: 1),
  Size size = const Size(1300, 2000),
}) {
  return pumpAdminScreens(
    tester,
    size: size,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SchedulesScreen()),
      GoRoute(
        path: '/otra',
        builder: (context, state) =>
            const Scaffold(body: Text('Otra pantalla')),
      ),
    ],
    overrides: scheduleTestOverrides(repository, pollInterval: pollInterval),
  );
}

/// Monta la pantalla sin esperar a que se aquiete: para ver el estado de un
/// primer pedido que sigue pendiente (el cargando nunca se aquieta).
Future<void> _pumpUnsettled(
  WidgetTester tester,
  RecordingScheduleRepository repository,
) async {
  tester.view.physicalSize = const Size(1300, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: scheduleTestOverrides(repository),
      child: const MaterialApp(home: SchedulesScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> _search(WidgetTester tester) async {
  await tester.tap(find.text('Buscar'));
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('al abrir', () {
    _test('muestra el título, la barra y las cinco consultas del día', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository();

      await _pump(tester, repository);

      expect(find.text('Agendas'), findsOneWidget);
      expect(find.byType(ScheduleFilterBar), findsOneWidget);
      expect(find.byType(ScheduleResults), findsOneWidget);
      for (final name in _members) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('5 consultas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repository.calls, hasLength(1));
    });

    _test('mientras el primer pedido está pendiente muestra el spinner y '
        'ningún resultado', (tester) async {
      final repository = RecordingScheduleRepository()
        ..gate = Completer<SchedulePage>();

      await _pumpUnsettled(tester, repository);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ScheduleResults), findsNothing);
      for (final name in _members) {
        expect(find.text(name), findsNothing, reason: name);
      }
      // La barra de filtros ya se puede usar.
      expect(find.byType(ScheduleFilterBar), findsOneWidget);
    });
  });

  group('scroll', () {
    _test('con una ventana chica se llega al último resultado y al paginador '
        'haciendo scroll', (tester) async {
      await _pump(
        tester,
        RecordingScheduleRepository(),
        size: const Size(800, 600),
      );
      expect(tester.takeException(), isNull);

      // Con 600 px de alto no entra todo: lo de abajo no está a la vista.
      expect(find.text('Pablo Sosa').hitTestable(), findsNothing);
      expect(find.text('Página 1 de 1').hitTestable(), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(CenteredContent),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Pablo Sosa'),
        200,
        scrollable: scrollable,
      );
      await tester.scrollUntilVisible(
        find.text('Página 1 de 1'),
        200,
        scrollable: scrollable,
      );

      expect(find.text('Pablo Sosa').hitTestable(), findsOneWidget);
      expect(find.text('Página 1 de 1').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('refresco', () {
    _test('con datos a la vista, un refresco pendiente no muestra el spinner '
        'y los datos siguen en pantalla', (tester) async {
      final repository = RecordingScheduleRepository();
      await _pump(tester, repository, pollInterval: null);
      expect(find.text('Ana Fernández'), findsOneWidget);

      repository.gate = Completer<SchedulePage>();
      await tester.pump(const Duration(seconds: 15));

      expect(repository.calls, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Ana Fernández'), findsOneWidget);
      expect(find.text('5 consultas'), findsOneWidget);
    });

    _test('a los 14 s hay 1 pedido, a los 15 s hay 2 y a los 30 s hay 3', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository();
      await _pump(tester, repository, pollInterval: null);
      expect(repository.calls, hasLength(1));

      await tester.pump(const Duration(seconds: 14));
      expect(repository.calls, hasLength(1));

      await tester.pump(const Duration(seconds: 1));
      expect(repository.calls, hasLength(2));

      await tester.pump(const Duration(seconds: 15));
      expect(repository.calls, hasLength(3));
    });

    _test('al salir de la pantalla no hay pedidos nuevos', (tester) async {
      final repository = RecordingScheduleRepository();
      final router = await _pump(tester, repository, pollInterval: null);
      expect(repository.calls, hasLength(1));

      router.go('/otra');
      await tester.pumpAndSettle();
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(find.byType(SchedulesScreen), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));

      expect(repository.calls, hasLength(1));
    });

    _test('si un refresco falla, se ve la lista y el aviso con "Reintentar"', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository();
      await _pump(tester, repository, pollInterval: null);
      expect(find.text('Ana Fernández'), findsOneWidget);

      repository.failure = const ApiException();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Ana Fernández'), findsOneWidget);
      expect(find.text(_genericLoadError), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    _test('con el error a la vista, el refresco no lo cambia por el spinner', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository()
        ..failure = const ApiException();
      await _pump(tester, repository, pollInterval: null);
      expect(find.text(_genericLoadError), findsOneWidget);

      // El próximo pedido queda pendiente: en ese momento la página está
      // cargando, pero el error no desaparece ni aparece el spinner.
      repository
        ..failure = null
        ..gate = Completer<SchedulePage>();
      await tester.pump(const Duration(seconds: 15));

      expect(repository.calls, hasLength(2));
      expect(find.text(_genericLoadError), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('filtros', () {
    _test('cambiar un filtro con Buscar hace un pedido nuevo con ese filtro', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository();
      await _pump(tester, repository);
      expect(repository.calls, hasLength(1));

      await _type(tester, 'filter-id', '9003');
      await _search(tester);

      expect(repository.calls, hasLength(2));
      expect(repository.calls.last.appointmentId, '9003');
      expect(repository.calls.last.toQueryParameters()['consultaId'], 9003);
      expect(find.text('Luis Martínez'), findsOneWidget);
      expect(find.text('Ana Fernández'), findsNothing);
      expect(find.text('1 consulta'), findsOneWidget);
    });

    _test('sin consultas para los filtros dice "No hay consultas con esos '
        'filtros." una sola vez', (tester) async {
      final repository = RecordingScheduleRepository();
      await _pump(tester, repository);

      // Una cédula válida que no tiene consultas ese día.
      await _type(tester, 'filter-ci', '12345672');
      await _search(tester);

      expect(find.text('No hay consultas con esos filtros.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      expect(repository.calls.last.ci, '12345672');
    });
  });

  group('errores', () {
    _test('una validación del servidor muestra su mensaje y "Reintentar"', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository()
        ..failure = const ScheduleValidationException('mensaje del servidor');

      await _pump(tester, repository);

      expect(find.text('mensaje del servidor'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text(_genericLoadError), findsNothing);
      expect(find.byType(ScheduleResults), findsNothing);
      // La pantalla no se rompe: la barra sigue y se puede corregir el filtro.
      expect(find.byType(ScheduleFilterBar), findsOneWidget);
    });

    _test('un error genérico muestra el mensaje genérico y "Reintentar"', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository()
        ..failure = const ApiException();

      await _pump(tester, repository);

      expect(find.text(_genericLoadError), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.byType(ScheduleFilterBar), findsOneWidget);
    });

    _test('un error que no es de la API no muestra texto técnico', (
      tester,
    ) async {
      final repository = RecordingScheduleRepository()
        ..failure = StateError('detalle técnico');

      await _pump(tester, repository);

      expect(find.text(_genericLoadError), findsOneWidget);
      expect(find.textContaining('detalle técnico'), findsNothing);
      expect(find.textContaining('Bad state'), findsNothing);
    });

    _test('"Reintentar" hace un pedido nuevo y, si ahora anda, muestra las '
        'consultas', (tester) async {
      final repository = RecordingScheduleRepository()
        ..failure = const ApiException();
      await _pump(tester, repository);
      expect(repository.calls, hasLength(1));
      expect(find.text(_genericLoadError), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(2));
      expect(find.text(_genericLoadError), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      for (final name in _members) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });

    _test('"Reintentar" pide con los mismos filtros', (tester) async {
      final repository = RecordingScheduleRepository()
        ..failure = const ApiException();
      await _pump(tester, repository);

      await tester.tap(find.text('Reintentar'));
      await tester.pump(const Duration(milliseconds: 1));

      expect(repository.calls, hasLength(2));
      expect(repository.calls.last, repository.calls.first);
      expect(repository.calls.last, isA<ScheduleFilters>());
    });
  });
}
