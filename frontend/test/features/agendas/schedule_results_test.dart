import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_filters_controller.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_today_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/widgets/schedule_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pager_layout.dart';
import '../../helpers/pump_admin.dart';

final DateTime _today = DateTime.utc(2026, 10, 26);

const Size _wide = Size(1300, 1800);
const Size _narrow = Size(400, 1800);

/// Las cinco consultas del repositorio falso, en una página.
/// Se pide con `runAsync`: en `testWidgets` el reloj es falso y el
/// `Future.delayed` del repositorio no avanzaría solo.
Future<SchedulePage> _fivePages(
  WidgetTester tester, {
  int page = 0,
  int total = 5,
}) async {
  final all = (await tester.runAsync(
    () => FakeScheduleRepository(
      latency: Duration.zero,
      today: _today,
    ).search(ScheduleFilters(date: _today)),
  ))!;
  return SchedulePage(items: all.items, page: page, size: 20, total: total);
}

SchedulePage _empty({int total = 0}) =>
    SchedulePage(items: const [], page: 0, size: 20, total: total);

Future<void> _pump(
  WidgetTester tester,
  SchedulePage page, {
  Size size = _wide,
}) async {
  await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(child: ScheduleResults(page: page)),
        ),
      ),
    ],
    overrides: [schedulesTodayProvider.overrideWithValue(_today)],
  );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ScheduleResults)));

void main() {
  group('pantalla ancha: tabla', () {
    testWidgets('muestra la tabla con 5 filas y el total "5 consultas"', (
      tester,
    ) async {
      await _pump(tester, await _fivePages(tester));

      expect(find.byType(DataTable), findsOneWidget);
      expect(
        tester.widget<DataTable>(find.byType(DataTable)).rows,
        hasLength(5),
      );
      expect(find.byType(Card), findsNothing);
      expect(find.text('5 consultas'), findsOneWidget);
    });

    testWidgets('con una sola consulta dice "1 consulta"', (tester) async {
      final all = await _fivePages(tester);
      await _pump(
        tester,
        SchedulePage(items: [all.items.first], page: 0, size: 20, total: 1),
      );

      expect(find.text('1 consulta'), findsOneWidget);
      expect(find.text('1 consultas'), findsNothing);
    });

    testWidgets('las columnas de la tabla', (tester) async {
      await _pump(tester, await _fivePages(tester));

      final table = tester.widget<DataTable>(find.byType(DataTable));
      final headers = [
        for (final column in table.columns) (column.label as Text).data,
      ];
      expect(headers, [
        'Consulta',
        'Socio',
        'Médico',
        'Fecha',
        'Hora',
        'Consultorio',
        'Estado',
        'Llegada',
      ]);
    });

    testWidgets('cada consulta muestra todos sus datos', (tester) async {
      await _pump(tester, await _fivePages(tester));

      // La 9001: Ana Fernández con Carla Méndez, de 09:00 a 09:20.
      expect(find.text('9001'), findsOneWidget);
      expect(find.text('Ana Fernández'), findsOneWidget);
      expect(find.text('CI 90000046'), findsOneWidget);
      expect(find.text('Carla Méndez'), findsNWidgets(2));
      expect(find.text('Medicina General'), findsNWidgets(2));
      expect(find.text('26/10/2026'), findsNWidgets(5));
      expect(find.text('09:00 - 09:20'), findsOneWidget);
      expect(find.text('Consultorio 3'), findsNWidgets(2));
      expect(find.text('Agendada'), findsNWidgets(2));
    });

    testWidgets(
      'la 9001 llegó a las 08:55 y la 9002 a las 08:40 (No atendida); '
      'las otras tres dicen "Sin aviso"',
      (tester) async {
        await _pump(tester, await _fivePages(tester));

        expect(find.text('08:55'), findsOneWidget);
        expect(find.text('Ana Fernández'), findsOneWidget);
        expect(find.text('08:40'), findsOneWidget);
        expect(find.text('No atendida'), findsOneWidget);
        expect(find.text('Sin aviso'), findsNWidgets(3));
      },
    );

    testWidgets('los estados salen en español', (tester) async {
      await _pump(tester, await _fivePages(tester));

      expect(find.text('Atendida'), findsOneWidget);
      expect(find.text('Cancelada por el socio'), findsOneWidget);
      expect(find.text('CANCELADA_SOCIO'), findsNothing);
    });
  });

  group('pantalla angosta: tarjetas', () {
    testWidgets('muestra 5 tarjetas y ninguna tabla', (tester) async {
      await _pump(tester, await _fivePages(tester), size: _narrow);

      expect(find.byType(Card), findsNWidgets(5));
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('5 consultas'), findsOneWidget);
    });

    testWidgets('cada tarjeta muestra los datos de la consulta', (
      tester,
    ) async {
      await _pump(tester, await _fivePages(tester), size: _narrow);

      expect(find.text('Consulta 9001'), findsOneWidget);
      expect(find.text('Ana Fernández'), findsOneWidget);
      expect(find.text('CI 90000046'), findsOneWidget);
      expect(find.text('Carla Méndez'), findsNWidgets(2));
      expect(find.text('Medicina General'), findsNWidgets(2));
      expect(find.text('26/10/2026'), findsNWidgets(5));
      expect(find.text('09:00 - 09:20'), findsOneWidget);
      expect(find.text('Consultorio 3'), findsNWidgets(2));
    });

    testWidgets(
      'la 9001 llegó a las 08:55 y la 9002 a las 08:40 (No atendida); '
      'las otras tres dicen "Sin aviso"',
      (tester) async {
        await _pump(tester, await _fivePages(tester), size: _narrow);

        expect(find.text('08:55'), findsOneWidget);
        expect(find.text('08:40'), findsOneWidget);
        expect(find.text('No atendida'), findsOneWidget);
        expect(find.text('Sin aviso'), findsNWidgets(3));
      },
    );
  });

  group('sin resultados', () {
    testWidgets('una página vacía dice que no hay consultas y no pagina', (
      tester,
    ) async {
      await _pump(tester, _empty());

      expect(find.text('No hay consultas con esos filtros.'), findsOneWidget);
      expect(find.textContaining('Página'), findsNothing);
      expect(find.text('Anterior'), findsNothing);
      expect(find.text('Siguiente'), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.textContaining('consulta'), findsOneWidget);
    });

    testWidgets('una página vacía en pantalla angosta también', (tester) async {
      await _pump(tester, _empty(), size: _narrow);

      expect(find.text('No hay consultas con esos filtros.'), findsOneWidget);
      expect(find.text('Siguiente'), findsNothing);
    });

    testWidgets('una página sin filas pero con total deja volver atrás', (
      tester,
    ) async {
      // Pasa si el refresco encuentra menos consultas que antes.
      await _pump(
        tester,
        SchedulePage(items: const [], page: 3, size: 20, total: 41),
      );

      expect(find.text('No hay consultas con esos filtros.'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);
    });
  });

  testWidgets('a 320 px el paginador pone la página arriba y los botones '
      'lado a lado', (tester) async {
    await loadRoboto();
    await _pump(
      tester,
      await _fivePages(tester, total: 41),
      size: const Size(320, 1800),
    );
    final next = find.widgetWithText(OutlinedButton, 'Siguiente');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();

    expectNarrowPager(
      tester,
      label: find.text('Página 1 de 3'),
      previous: find.widgetWithText(OutlinedButton, 'Anterior'),
      next: next,
    );
  });

  group('paginación', () {
    OutlinedButton button(WidgetTester tester, String label) => tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label));

    testWidgets('con total 41 y size 20 muestra "Página 1 de 3", con '
        'Anterior deshabilitado y Siguiente habilitado', (tester) async {
      await _pump(tester, await _fivePages(tester, total: 41));

      expect(find.text('Página 1 de 3'), findsOneWidget);
      expect(find.text('41 consultas'), findsOneWidget);
      expect(button(tester, 'Anterior').onPressed, isNull);
      expect(button(tester, 'Siguiente').onPressed, isNotNull);
    });

    testWidgets('tocar Siguiente llama a goToPage(1) del controller', (
      tester,
    ) async {
      await _pump(tester, await _fivePages(tester, total: 41));
      final container = _containerOf(tester);
      // El controller es autoDispose: se lo mantiene vivo para leer su estado.
      container.listen(scheduleFiltersControllerProvider, (_, _) {});

      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 1));

      expect(container.read(scheduleFiltersControllerProvider).page, 1);
    });

    testWidgets('en la página del medio están los dos botones; Anterior va a '
        'la página 0', (tester) async {
      await _pump(tester, await _fivePages(tester, page: 1, total: 41));
      final container = _containerOf(tester);
      container.listen(scheduleFiltersControllerProvider, (_, _) {});
      container.read(scheduleFiltersControllerProvider.notifier).goToPage(1);

      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(button(tester, 'Anterior').onPressed, isNotNull);
      expect(button(tester, 'Siguiente').onPressed, isNotNull);

      await tester.tap(find.text('Anterior'));
      await tester.pump(const Duration(milliseconds: 1));

      expect(container.read(scheduleFiltersControllerProvider).page, 0);
    });

    testWidgets('en la última página no hay Siguiente', (tester) async {
      await _pump(tester, await _fivePages(tester, page: 2, total: 41));

      expect(find.text('Página 3 de 3'), findsOneWidget);
      expect(button(tester, 'Anterior').onPressed, isNotNull);
      expect(button(tester, 'Siguiente').onPressed, isNull);
    });

    testWidgets('con una sola página, los dos botones están deshabilitados', (
      tester,
    ) async {
      await _pump(tester, await _fivePages(tester));

      expect(find.text('Página 1 de 1'), findsOneWidget);
      expect(button(tester, 'Anterior').onPressed, isNull);
      expect(button(tester, 'Siguiente').onPressed, isNull);
    });
  });
}
