import 'dart:async';

import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_filters_controller.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_page_provider.dart';
import 'package:agenda_medica/features/agendas/widgets/schedule_filter_bar.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import 'schedule_test_support.dart';

/// Los médicos del selector no llegan: el repositorio de turnos no responde.
class _PendingDoctorsRepository implements ShiftRepository {
  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) =>
      Completer<List<Doctor>>().future;

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      throw UnimplementedError();

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => throw UnimplementedError();

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) =>
      throw UnimplementedError();
}

/// Mira la página, como hace la pantalla, para que los pedidos se hagan.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(schedulesPageProvider);
    return const Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: EdgeInsets.all(16), child: ScheduleFilterBar()),
      ),
    );
  }
}

Future<RecordingScheduleRepository> _pump(
  WidgetTester tester, {
  ShiftRepositoryFactory? shiftRepository,
}) async {
  final repository = RecordingScheduleRepository();
  await pumpAdminScreens(
    tester,
    size: const Size(1300, 1800),
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => const _Host())],
    overrides: scheduleTestOverrides(
      repository,
      shiftRepository: shiftRepository,
    ),
  );
  // Los médicos y el primer pedido de la página.
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpAndSettle();
  return repository;
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ScheduleFilterBar)));

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String _textOf(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

Future<void> _choose(WidgetTester tester, String key, String option) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester) async {
  await tester.tap(find.text('Buscar'));
  await tester.pump(const Duration(milliseconds: 1));
}

Map<String, Object> _lastQuery(RecordingScheduleRepository repository) =>
    repository.calls.last.toQueryParameters();

void main() {
  group('al abrir', () {
    testWidgets('la fecha es la de hoy y los demás filtros están vacíos', (
      tester,
    ) async {
      await _pump(tester);

      expect(_textOf(tester, 'filter-date'), '26/10/2026');
      expect(_textOf(tester, 'filter-ci'), '');
      expect(_textOf(tester, 'filter-id'), '');
      expect(find.text('Buscar'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('Ascendente'), findsOneWidget);
    });

    testWidgets('el primer pedido es el de hoy, por fecha y hora', (
      tester,
    ) async {
      final repository = await _pump(tester);

      expect(repository.calls, hasLength(1));
      expect(_lastQuery(repository), {
        'fecha': '2026-10-26',
        'orden': 'fechaHora',
        'sentido': 'asc',
        'page': 0,
        'size': 20,
      });
    });
  });

  group('cédula', () {
    testWidgets('una cédula inválida muestra el error y no hace pedidos', (
      tester,
    ) async {
      final repository = await _pump(tester);
      final before = repository.calls.length;

      await _type(tester, 'filter-ci', '1234567');
      await _search(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('La cédula no es válida'), findsOneWidget);
      expect(repository.calls, hasLength(before));
    });

    testWidgets('"9.000.004-6" se busca como 90000046', (tester) async {
      final repository = await _pump(tester);

      await _type(tester, 'filter-ci', '9.000.004-6');
      await _search(tester);

      expect(_lastQuery(repository)['ci'], '90000046');
      expect(repository.calls.last.ci, '90000046');
    });

    testWidgets('un campo vacío no es un filtro ni un error', (tester) async {
      final repository = await _pump(tester);

      await _search(tester);

      expect(find.textContaining('La cédula'), findsNothing);
      expect(_lastQuery(repository).containsKey('ci'), isFalse);
    });

    testWidgets('después de corregirla, busca', (tester) async {
      final repository = await _pump(tester);
      await _type(tester, 'filter-ci', '1234567');
      await _search(tester);
      await tester.pumpAndSettle();
      final before = repository.calls.length;

      await _type(tester, 'filter-ci', '90000046');
      await _search(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('La cédula no es válida'), findsNothing);
      expect(repository.calls, hasLength(before + 1));
      expect(_lastQuery(repository)['ci'], '90000046');
    });
  });

  group('identificador', () {
    testWidgets('escribir 15 y buscar manda consultaId=15', (tester) async {
      final repository = await _pump(tester);

      await _type(tester, 'filter-id', '15');
      await _search(tester);

      expect(_lastQuery(repository)['consultaId'], 15);
    });

    testWidgets('no acepta letras', (tester) async {
      await _pump(tester);

      await _type(tester, 'filter-id', 'abc');
      expect(_textOf(tester, 'filter-id'), '');

      await _type(tester, 'filter-id', '1a2b3');
      expect(_textOf(tester, 'filter-id'), '123');
    });

    testWidgets('vacío no se manda', (tester) async {
      final repository = await _pump(tester);

      await _search(tester);

      expect(_lastQuery(repository).containsKey('consultaId'), isFalse);
    });
  });

  group('fecha', () {
    testWidgets('otra fecha escrita se busca con ese día', (tester) async {
      final repository = await _pump(tester);

      await _type(tester, 'filter-date', '27/10/2026');
      await _search(tester);

      expect(_lastQuery(repository)['fecha'], '2026-10-27');
    });

    testWidgets('sin fecha pide la fecha y no busca', (tester) async {
      final repository = await _pump(tester);
      final before = repository.calls.length;

      await _type(tester, 'filter-date', '');
      await _search(tester);
      await tester.pumpAndSettle();

      expect(find.text('Ingresá la fecha.'), findsOneWidget);
      expect(repository.calls, hasLength(before));
    });

    testWidgets('una fecha que no existe muestra el error del campo y no '
        'busca', (tester) async {
      final repository = await _pump(tester);
      final before = repository.calls.length;

      await _type(tester, 'filter-date', '31/02/2026');
      await _search(tester);
      await tester.pumpAndSettle();

      expect(find.text(kUiDateNonexistentMessage), findsOneWidget);
      expect(repository.calls, hasLength(before));
    });

    testWidgets('una fecha a medias no se busca', (tester) async {
      final repository = await _pump(tester);
      final before = repository.calls.length;

      await _type(tester, 'filter-date', '27/10');
      await _search(tester);
      await tester.pumpAndSettle();

      expect(find.text(kUiDateBadFormatMessage), findsOneWidget);
      expect(repository.calls, hasLength(before));
    });
  });

  group('médico', () {
    testWidgets('el desplegable ofrece "Todos" y los médicos del selector', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('filter-doctor')));
      await tester.pumpAndSettle();

      expect(find.text('Carla Méndez'), findsOneWidget);
      expect(find.text('Esteban Silva'), findsOneWidget);
      expect(find.text('Florencia Acosta'), findsOneWidget);
    });

    testWidgets('elegir un médico manda medicoId con su id', (tester) async {
      final repository = await _pump(tester);

      await _choose(tester, 'filter-doctor', 'Esteban Silva');
      await _search(tester);

      expect(_lastQuery(repository)['medicoId'], 6);
    });

    testWidgets('con los médicos sin cargar, el desplegable solo tiene '
        '"Todos" y la pantalla sigue andando', (tester) async {
      final repository = await _pump(
        tester,
        shiftRepository: _PendingDoctorsRepository.new,
      );

      await tester.tap(find.byKey(const Key('filter-doctor')));
      await tester.pumpAndSettle();
      expect(find.text('Todos'), findsWidgets);
      expect(find.text('Esteban Silva'), findsNothing);
      await tester.tap(find.text('Todos').last);
      await tester.pumpAndSettle();

      await _type(tester, 'filter-id', '9001');
      await _search(tester);

      expect(_lastQuery(repository)['consultaId'], 9001);
      expect(_lastQuery(repository).containsKey('medicoId'), isFalse);
    });
  });

  group('estado', () {
    testWidgets('ofrece "Todos" y los siete estados en español', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('filter-status')));
      await tester.pumpAndSettle();

      for (final label in [
        'Agendada',
        'Atendida',
        'Cancelada por el socio',
        'Cancelada por la institución',
        'No se presentó',
        'No asistió',
        'No atendida',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('elegir un estado manda estado con el nombre exacto', (
      tester,
    ) async {
      final repository = await _pump(tester);

      await _choose(tester, 'filter-status', 'Cancelada por la institución');
      await _search(tester);

      expect(_lastQuery(repository)['estado'], 'CANCELADA_INSTITUCION');
    });

    testWidgets('"No atendida" manda NO_ATENDIDA', (tester) async {
      final repository = await _pump(tester);

      await _choose(tester, 'filter-status', 'No atendida');
      await _search(tester);

      expect(_lastQuery(repository)['estado'], 'NO_ATENDIDA');
    });
  });

  group('llegada', () {
    testWidgets('por defecto es "Todas" y no se manda', (tester) async {
      final repository = await _pump(tester);

      await _search(tester);

      expect(find.text('Todas'), findsOneWidget);
      expect(_lastQuery(repository).containsKey('llegada'), isFalse);
    });

    testWidgets('"Con aviso de llegada" manda llegada=true', (tester) async {
      final repository = await _pump(tester);

      await _choose(tester, 'filter-arrived', 'Con aviso de llegada');
      await _search(tester);

      expect(_lastQuery(repository)['llegada'], true);
    });

    testWidgets('"Sin aviso de llegada" manda llegada=false', (tester) async {
      final repository = await _pump(tester);

      await _choose(tester, 'filter-arrived', 'Sin aviso de llegada');
      await _search(tester);

      expect(_lastQuery(repository)['llegada'], false);
    });
  });

  group('los filtros vacíos no se mandan', () {
    testWidgets('con todo en blanco solo van fecha, orden, sentido y página', (
      tester,
    ) async {
      final repository = await _pump(tester);

      await _search(tester);

      expect(_lastQuery(repository).keys.toSet(), {
        'fecha',
        'orden',
        'sentido',
        'page',
        'size',
      });
    });
  });

  group('orden y sentido se aplican al instante', () {
    testWidgets('"Hora de llegada" pide por hora de llegada', (tester) async {
      final repository = await _pump(tester);
      final before = repository.calls.length;

      await _choose(tester, 'filter-order', 'Hora de llegada');
      await tester.pump(const Duration(milliseconds: 1));

      expect(repository.calls, hasLength(before + 1));
      expect(_lastQuery(repository)['orden'], 'horaLlegada');
    });

    testWidgets('tocar "Ascendente" pasa a "Descendente" y pide desc', (
      tester,
    ) async {
      final repository = await _pump(tester);

      await tester.tap(find.text('Ascendente'));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(find.text('Descendente'), findsOneWidget);
      expect(_lastQuery(repository)['sentido'], 'desc');
    });

    testWidgets('el orden no pisa lo escrito y todavía no buscado', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await _type(tester, 'filter-id', '15');

      await _choose(tester, 'filter-order', 'Hora de llegada');
      await tester.pump(const Duration(milliseconds: 1));

      expect(_textOf(tester, 'filter-id'), '15');
      expect(_lastQuery(repository).containsKey('consultaId'), isFalse);
    });
  });

  group('cambiar un filtro estando en la página 3 manda page=0', () {
    final changes = <String, Future<void> Function(WidgetTester)>{
      'la cédula': (t) => _type(t, 'filter-ci', '90000046'),
      'el identificador': (t) => _type(t, 'filter-id', '15'),
      'el médico': (t) => _choose(t, 'filter-doctor', 'Carla Méndez'),
      'la fecha': (t) => _type(t, 'filter-date', '27/10/2026'),
      'el estado': (t) => _choose(t, 'filter-status', 'Atendida'),
      'la llegada': (t) => _choose(t, 'filter-arrived', 'Con aviso de llegada'),
    };

    for (final entry in changes.entries) {
      testWidgets(entry.key, (tester) async {
        final repository = await _pump(tester);
        final container = _containerOf(tester);
        container.read(scheduleFiltersControllerProvider.notifier).goToPage(3);
        await tester.pump(const Duration(milliseconds: 1));
        expect(repository.calls.last.page, 3);

        await entry.value(tester);
        await _search(tester);

        expect(repository.calls.last.page, 0);
      });
    }

    testWidgets('el orden', (tester) async {
      final repository = await _pump(tester);
      _containerOf(tester)
          .read(scheduleFiltersControllerProvider.notifier)
          .goToPage(3);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.calls.last.page, 3);

      await _choose(tester, 'filter-order', 'Hora de llegada');
      await tester.pump(const Duration(milliseconds: 1));

      expect(repository.calls.last.page, 0);
    });

    testWidgets('el sentido', (tester) async {
      final repository = await _pump(tester);
      _containerOf(tester)
          .read(scheduleFiltersControllerProvider.notifier)
          .goToPage(3);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.calls.last.page, 3);

      await tester.tap(find.text('Ascendente'));
      await tester.pump(const Duration(milliseconds: 1));

      expect(repository.calls.last.page, 0);
    });
  });

  group('Limpiar', () {
    testWidgets('vuelve a los valores por defecto y vacía los campos', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await _type(tester, 'filter-ci', '90000046');
      await _type(tester, 'filter-id', '9001');
      await _type(tester, 'filter-date', '27/10/2026');
      await _choose(tester, 'filter-doctor', 'Carla Méndez');
      await _choose(tester, 'filter-status', 'Atendida');
      await _choose(tester, 'filter-arrived', 'Sin aviso de llegada');
      await _search(tester);
      await _choose(tester, 'filter-order', 'Hora de llegada');
      await tester.tap(find.text('Ascendente'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.calls.last.ci, '90000046');
      expect(repository.calls.last.ascending, isFalse);

      await tester.tap(find.text('Limpiar'));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(repository.calls.last, ScheduleFilters(date: scheduleTestToday));
      expect(_textOf(tester, 'filter-ci'), '');
      expect(_textOf(tester, 'filter-id'), '');
      expect(_textOf(tester, 'filter-date'), '26/10/2026');
      expect(find.text('Carla Méndez'), findsNothing);
      expect(find.text('Atendida'), findsNothing);
      expect(find.text('Sin aviso de llegada'), findsNothing);
      expect(find.text('Hora de llegada'), findsNothing);
      expect(find.text('Ascendente'), findsOneWidget);
    });

    testWidgets('también borra un error de la cédula', (tester) async {
      await _pump(tester);
      await _type(tester, 'filter-ci', '1234567');
      await _search(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('La cédula no es válida'), findsOneWidget);

      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('La cédula no es válida'), findsNothing);
    });

    testWidgets('estando en la página 3 vuelve a la 0', (tester) async {
      final repository = await _pump(tester);
      _containerOf(tester)
          .read(scheduleFiltersControllerProvider.notifier)
          .goToPage(3);
      await tester.pump(const Duration(milliseconds: 1));

      await tester.tap(find.text('Limpiar'));
      await tester.pump(const Duration(milliseconds: 1));

      expect(repository.calls.last.page, 0);
    });
  });
}
