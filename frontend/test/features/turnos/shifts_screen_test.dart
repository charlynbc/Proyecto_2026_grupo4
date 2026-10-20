import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import '../../helpers/shift_listing_data.dart';

/// Ancho de pantalla de los tests de la tabla: sobra para que entre.
const Size _wideScreen = Size(1300, 1800);

/// Falla la primera vez que se pide el listado, como un corte de red.
class _FlakyShiftRepository extends FakeShiftRepository {
  _FlakyShiftRepository(super.db) : super(latency: Duration.zero);

  int calls = 0;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    calls++;
    if (calls == 1) throw const ApiException();
    return super.listShifts(filters);
  }
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  Size size = _wideScreen,
  ShiftRepository Function(FakeShiftDatabase db)? repository,
}) {
  final admin = FakeAdminDatabase();
  final shiftDb = buildListingDb(admin);
  return pumpAdminScreens(
    tester,
    size: size,
    initialLocation: kShiftsPath,
    routes: [
      GoRoute(path: kShiftsPath, builder: (_, _) => const ShiftsScreen()),
      GoRoute(
        path: kNewWeeklyShiftPath,
        builder: (_, _) => const Scaffold(body: Text('Alta de turno semanal')),
      ),
    ],
    overrides: [
      shiftRepositoryProvider.overrideWith(
        (ref) async =>
            repository?.call(shiftDb) ??
            FakeShiftRepository(shiftDb, latency: Duration.zero),
      ),
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
      ),
    ],
  );
}

/// Las filas de la tabla: una lista de textos por fila, en el orden de las
/// columnas de RF-17.
List<List<String>> _rows(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    [for (final cell in row.cells) (cell.child as Text).data!],
];

const _date = 0;
const _doctor = 1;
const _specialty = 2;
const _weekday = 3;
const _state = 7;

Finder get _search => find.widgetWithText(FilledButton, 'Buscar');

Future<void> _choose(WidgetTester tester, Key key, String option) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(_search);
  await tester.pumpAndSettle();
}

Future<void> _typeDate(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextField, label), text);

/// Cuánto se puede desplazar la tabla hacia los costados: 0 si entra entera.
double _tableOverflow(WidgetTester tester) {
  final horizontal = find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
  );
  final scrollable = find.descendant(
    of: horizontal,
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position.maxScrollExtent;
}

void main() {
  // Los anchos se miden con la tipografía real, no con Ahem.
  setUpAll(loadRoboto);

  group('la tabla', () {
    testWidgets('muestra las columnas de RF-17 y la primera página', (
      tester,
    ) async {
      await _pump(tester);

      for (final header in [
        'Fecha',
        'Médico',
        'Especialidad',
        'Día',
        'Horario',
        'Consultorio',
        'Números',
        'Estado',
      ]) {
        expect(
          find.descendant(
            of: find.byType(DataTable),
            matching: find.text(header),
          ),
          findsOneWidget,
          reason: header,
        );
      }
      expect(_rows(tester), hasLength(20));
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('cada fila trae fecha, médico, horario y estado', (
      tester,
    ) async {
      await _pump(tester);

      expect(_rows(tester)[0], [
        '19/10/2026',
        'Esteban Silva',
        'Cardiología',
        'Lunes',
        '08:00 – 08:20',
        'Consultorio 7',
        '1',
        'Activa',
      ]);
      expect(_rows(tester)[1], [
        '19/10/2026',
        'Florencia Acosta',
        'Dermatología',
        'Lunes',
        '10:00 – 11:00',
        'Consultorio 12',
        '3',
        'Activa',
      ]);
      expect(
        _rows(tester).where((r) => r[_state] == 'Suspendida'),
        hasLength(2),
      );
    });
  });

  group('paginación', () {
    testWidgets('"Siguiente" pide la segunda página al servidor', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(_rows(tester), hasLength(12));
      expect(find.text('Página 2 de 2 · 32 turnos'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Siguiente'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(_rows(tester), hasLength(20));
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('en la primera página "Anterior" está deshabilitado', (
      tester,
    ) async {
      await _pump(tester);

      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Anterior'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('al buscar de nuevo vuelve a la primera página', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      await _choose(tester, const Key('filter-weekday'), 'Lunes');
      await _apply(tester);

      expect(find.text('Página 1 de 2 · 24 turnos'), findsOneWidget);
    });
  });

  group('filtros', () {
    testWidgets('por médico, recién al apretar "Buscar"', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      // Todavía no se aplicó.
      expect(_rows(tester), hasLength(20));
      await _apply(tester);

      expect(_rows(tester), hasLength(4));
      expect(_rows(tester).every((r) => r[_doctor] == 'Carla Méndez'), isTrue);
      expect(find.text('Página 1 de 1 · 4 turnos'), findsOneWidget);
    });

    testWidgets('por especialidad', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-specialty'), 'Cardiología');
      await _apply(tester);

      expect(_rows(tester), hasLength(5));
      expect(
        _rows(tester).every((r) => r[_specialty] == 'Cardiología'),
        isTrue,
      );
    });

    testWidgets('por día de la semana', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-weekday'), 'Martes');
      await _apply(tester);

      expect(_rows(tester), hasLength(4));
      expect(_rows(tester).every((r) => r[_weekday] == 'Martes'), isTrue);
    });

    testWidgets('por estado', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-state'), 'Suspendida');
      await _apply(tester);

      expect(_rows(tester), hasLength(2));
      expect(_rows(tester).every((r) => r[_state] == 'Suspendida'), isTrue);
      expect(find.text('Página 1 de 1 · 2 turnos'), findsOneWidget);
    });

    testWidgets('por rango de fechas, con los dos extremos incluidos', (
      tester,
    ) async {
      await _pump(tester);

      await _typeDate(tester, 'Desde', '20/10/2026');
      await _typeDate(tester, 'Hasta', '22/10/2026');
      await _apply(tester);

      expect(_rows(tester).map((r) => r[_date]), ['20/10/2026', '22/10/2026']);
    });

    testWidgets('los filtros se combinan', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      await _choose(tester, const Key('filter-state'), 'Suspendida');
      await _apply(tester);

      expect(_rows(tester).map((r) => r[_date]), ['27/10/2026']);
      expect(find.text('Página 1 de 1 · 1 turno'), findsOneWidget);
    });

    testWidgets('volver a "Todos" quita el filtro', (tester) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      await _apply(tester);
      expect(_rows(tester), hasLength(4));

      await _choose(tester, const Key('filter-doctor'), 'Todos');
      await _apply(tester);

      expect(_rows(tester), hasLength(20));
    });

    testWidgets('un "Desde" posterior a "Hasta" avisa y no busca', (
      tester,
    ) async {
      await _pump(tester);

      await _typeDate(tester, 'Desde', '01/11/2026');
      await _typeDate(tester, 'Hasta', '01/10/2026');
      await _apply(tester);

      expect(
        find.text(
          'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
        ),
        findsOneWidget,
      );
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    for (final text in ['2026-10-20', '31/02/2026', '20/10']) {
      testWidgets('la fecha "$text" no se acepta', (tester) async {
        await _pump(tester);

        await _typeDate(tester, 'Desde', text);
        await _apply(tester);

        expect(
          find.text(
            'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.',
          ),
          findsOneWidget,
        );
        expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
      });
    }
  });

  group('orden', () {
    testWidgets('por defecto: fecha y horario, ascendente', (tester) async {
      await _pump(tester);

      expect(find.text('Ascendente'), findsOneWidget);
      expect(_rows(tester).first[_date], '19/10/2026');
    });

    testWidgets('el sentido se invierte apenas se toca', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Ascendente'));
      await tester.pumpAndSettle();

      expect(find.text('Descendente'), findsOneWidget);
      expect(_rows(tester).first[_date], '22/03/2027');
    });

    testWidgets('por médico', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-order'), 'Médico');

      expect(_rows(tester).first[_doctor], 'Florencia Acosta');
      await tester.tap(find.text('Ascendente'));
      await tester.pumpAndSettle();
      expect(_rows(tester).first[_doctor], 'Esteban Silva');
    });

    testWidgets('por especialidad', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-order'), 'Especialidad');

      expect(_rows(tester).first[_specialty], 'Cardiología');
    });

    testWidgets('cambiar el orden vuelve a la primera página', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      await _choose(tester, const Key('filter-order'), 'Médico');

      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('ordenar no pierde los filtros aplicados', (tester) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-doctor'), 'Esteban Silva');
      await _apply(tester);

      await _choose(tester, const Key('filter-order'), 'Especialidad');

      expect(_rows(tester), hasLength(5));
    });
  });

  group('sin resultados y con errores', () {
    testWidgets('sin coincidencias avisa que no hay turnos', (tester) async {
      await _pump(tester);

      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      await _choose(tester, const Key('filter-weekday'), 'Lunes');
      await _apply(tester);

      expect(
        find.text(
          'No se encontraron turnos con esos filtros. Cambiá los criterios y '
          'volvé a buscar.',
        ),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Siguiente'), findsNothing);
    });

    testWidgets('si falla la carga, avisa y "Reintentar" vuelve a pedir', (
      tester,
    ) async {
      late _FlakyShiftRepository flaky;
      await _pump(
        tester,
        repository: (db) => flaky = _FlakyShiftRepository(db),
      );

      expect(
        find.text('No pudimos cargar los turnos. Intentá de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(flaky.calls, 2);
      expect(
        find.text('No pudimos cargar los turnos. Intentá de nuevo.'),
        findsNothing,
      );
      expect(_rows(tester), hasLength(20));
    });
  });

  group('según el ancho de la pantalla', () {
    const columns = [
      'Fecha',
      'Médico',
      'Especialidad',
      'Día',
      'Horario',
      'Consultorio',
      'Números',
      'Estado',
    ];

    for (final width in [500.0, 700.0]) {
      testWidgets('con $width px la tabla no entra y se usan tarjetas', (
        tester,
      ) async {
        await _pump(tester, size: Size(width, 1800));

        expect(find.byType(DataTable), findsNothing);
        expect(find.byType(Card), findsNWidgets(20));
        expect(find.textContaining('Esteban Silva'), findsWidgets);
        expect(find.textContaining('Suspendida'), findsWidgets);
      });
    }

    for (final width in [1100.0, 1300.0]) {
      testWidgets('con $width px entra la tabla completa, sin desplazarla', (
        tester,
      ) async {
        await _pump(tester, size: Size(width, 1800));

        expect(find.byType(Card), findsNothing);
        for (final column in columns) {
          final header = find.descendant(
            of: find.byType(DataTable),
            matching: find.text(column),
          );
          expect(header, findsOneWidget, reason: column);
          expect(
            tester.getTopRight(header).dx,
            lessThanOrEqualTo(width),
            reason: 'la columna $column se sale de la pantalla',
          );
        }
        expect(_tableOverflow(tester), 0);
      });
    }

    testWidgets('al angostar la ventana pasa de tabla a tarjetas', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(DataTable), findsOneWidget);

      tester.view.physicalSize = const Size(400, 1800);
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsNWidgets(20));
    });
  });

  testWidgets('"Nuevo turno semanal" lleva al formulario de alta', (
    tester,
  ) async {
    final router = await _pump(tester);

    await tester.tap(find.text('Nuevo turno semanal'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), kNewWeeklyShiftPath);
    expect(find.text('Alta de turno semanal'), findsOneWidget);
  });
}
