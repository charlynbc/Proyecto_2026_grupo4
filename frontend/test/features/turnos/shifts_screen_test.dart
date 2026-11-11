import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
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
/// columnas de RF-17. La celda del enlace no es texto y no entra en la lista.
List<List<String>> _rows(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    [
      for (final cell in row.cells)
        if (cell.child is Text) (cell.child as Text).data!,
    ],
];

// Los mensajes se escriben a mano: así una mutación del texto se detecta.
const String _badDateFormat =
    'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.';
const String _nonexistentDate =
    'Esa fecha no existe en el calendario. Revisá el día y el mes.';

const String _pickFrom = 'Elegir la fecha desde';
const String _pickTo = 'Elegir la fecha hasta';
const String _clearDate = 'Borrar la fecha';

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

Future<void> _typeDate(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

/// Lo que hay escrito en el campo de fecha con esa etiqueta.
String _fieldText(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

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

    // Lo que se escribe, lo que queda en el campo tras el filtro de caracteres
    // (solo dígitos y barras), el mensaje y si ya se ve antes de apretar
    // "Buscar": el error aparece al completar los 10 caracteres o al soltar el
    // foco, no al primer carácter.
    for (final c in [
      (
        typed: '2026-10-20',
        shown: '20261020',
        message: _badDateFormat,
        visibleBeforeSearch: false,
      ),
      (
        typed: '31/02/2026',
        shown: '31/02/2026',
        message: _nonexistentDate,
        visibleBeforeSearch: true,
      ),
      (
        typed: '20/10',
        shown: '20/10',
        message: _badDateFormat,
        visibleBeforeSearch: false,
      ),
    ]) {
      testWidgets('la fecha "${c.typed}" no se acepta y no busca', (
        tester,
      ) async {
        await _pump(tester);
        // Un filtro pendiente: si "Buscar" buscara igual, la lista cambiaría.
        await _choose(tester, const Key('filter-state'), 'Suspendida');

        await _typeDate(tester, 'Desde', c.typed);

        expect(_fieldText(tester, 'Desde'), c.shown);
        expect(
          find.text(c.message),
          c.visibleBeforeSearch ? findsOneWidget : findsNothing,
          reason: 'antes de apretar "Buscar"',
        );

        await _apply(tester);

        expect(find.text(c.message), findsOneWidget);
        expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
      });
    }

    testWidgets('Enter en "Desde" con 20/10 no busca y muestra el error', (
      tester,
    ) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      await _apply(tester);
      expect(_rows(tester), hasLength(4));
      // Pendiente, sin aplicar: si Enter buscara, quedarían 1 solo turno.
      await _choose(tester, const Key('filter-state'), 'Suspendida');
      await _typeDate(tester, 'Desde', '20/10');
      expect(find.text(_badDateFormat), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text(_badDateFormat), findsOneWidget);
      expect(_rows(tester), hasLength(4));
      expect(find.text('Página 1 de 1 · 4 turnos'), findsOneWidget);
    });

    testWidgets('Enter con una fecha válida sí busca', (tester) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '20/10/2026');
      await _typeDate(tester, 'Hasta', '22/10/2026');

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(_rows(tester).map((r) => r[_date]), ['20/10/2026', '22/10/2026']);
    });
  });

  group('el calendario y la cruz de las fechas', () {
    testWidgets('el calendario de "Hasta" abre en la fecha de "Desde"', (
      tester,
    ) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '10/11/2026');

      await tester.tap(find.byTooltip(_pickTo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 'Hasta'), '10/11/2026');
    });

    testWidgets('el calendario de "Desde" abre en lo que ya está escrito', (
      tester,
    ) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '10/11/2026');

      await tester.tap(find.byTooltip(_pickFrom));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 'Desde'), '10/11/2026');
    });

    testWidgets('elegir un día escribe la fecha en dd/mm/aaaa', (tester) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '10/11/2026');

      await tester.tap(find.byTooltip(_pickFrom));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 'Desde'), '15/11/2026');
    });

    testWidgets('la cruz borra la fecha y "Buscar" vuelve a traer todo', (
      tester,
    ) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '20/10/2026');
      await _typeDate(tester, 'Hasta', '22/10/2026');
      await _apply(tester);
      expect(_rows(tester), hasLength(2));

      // Primero queda la de "Desde"; al borrarla, la que sigue es la de "Hasta".
      await tester.tap(find.byTooltip(_clearDate).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_clearDate).first);
      await tester.pumpAndSettle();
      expect(_fieldText(tester, 'Desde'), isEmpty);
      expect(_fieldText(tester, 'Hasta'), isEmpty);
      await _apply(tester);

      expect(_rows(tester), hasLength(20));
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('una fecha que no existe lo dice al completarla', (
      tester,
    ) async {
      await _pump(tester);

      await _typeDate(tester, 'Hasta', '31/02/2026');

      expect(find.text(_nonexistentDate), findsOneWidget);
      expect(find.text(_badDateFormat), findsNothing);
    });
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

  group('Limpiar filtros', () {
    Finder clearButton() => find.text('Limpiar filtros');

    /// Lo que muestra el desplegable con esa clave (null = "Todos" o "Todas").
    T? selected<T>(WidgetTester tester, String key) => tester
        .widget<DropdownButton<T>>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(DropdownButton<T>),
          ),
        )
        .value;

    Future<void> clear(WidgetTester tester) async {
      await tester.tap(clearButton());
      await tester.pumpAndSettle();
    }

    bool anyDateFieldFocused(WidgetTester tester) => tester
        .widgetList<EditableText>(find.byType(EditableText))
        .any((field) => field.focusNode.hasFocus);

    testWidgets('está en la misma fila que "Buscar" y a su derecha', (
      tester,
    ) async {
      await _pump(tester);

      // `byType` compara el tipo exacto y los botones con ícono son una
      // subclase privada: se busca por `is`.
      Finder buttonWith(Finder label) => find.ancestor(
        of: label,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final search = tester.getRect(buttonWith(find.text('Buscar')));
      final clearRect = tester.getRect(buttonWith(clearButton()));

      expect(clearRect.left, greaterThan(search.right));
      expect((clearRect.center.dy - search.center.dy).abs(), lessThan(8));
    });

    testWidgets('vuelve los cuatro desplegables a Todos y Todas', (
      tester,
    ) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      await _choose(tester, const Key('filter-specialty'), 'Medicina General');
      await _choose(tester, const Key('filter-weekday'), 'Martes');
      await _choose(tester, const Key('filter-state'), 'Suspendida');
      await _apply(tester);
      // Antes de limpiar, los cuatro están elegidos y la búsqueda los aplicó.
      expect(selected<int?>(tester, 'filter-doctor'), isNotNull);
      expect(selected<int?>(tester, 'filter-specialty'), isNotNull);
      expect(selected<int?>(tester, 'filter-weekday'), isNotNull);
      expect(selected<ShiftState?>(tester, 'filter-state'), isNotNull);
      expect(_rows(tester), hasLength(1));

      await clear(tester);

      expect(selected<int?>(tester, 'filter-doctor'), isNull);
      expect(selected<int?>(tester, 'filter-specialty'), isNull);
      expect(selected<int?>(tester, 'filter-weekday'), isNull);
      expect(selected<ShiftState?>(tester, 'filter-state'), isNull);
    });

    testWidgets('vacía las dos fechas', (tester) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '20/10/2026');
      await _typeDate(tester, 'Hasta', '22/10/2026');
      await _apply(tester);
      expect(_fieldText(tester, 'Desde'), '20/10/2026');
      expect(_fieldText(tester, 'Hasta'), '22/10/2026');

      await clear(tester);

      expect(_fieldText(tester, 'Desde'), isEmpty);
      expect(_fieldText(tester, 'Hasta'), isEmpty);
    });

    testWidgets('deja el orden y el sentido por defecto', (tester) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-order'), 'Médico');
      await tester.tap(find.text('Ascendente'));
      await tester.pumpAndSettle();
      // Antes de limpiar: por médico y descendente (Silva primero).
      expect(selected<ShiftOrder>(tester, 'filter-order'), ShiftOrder.doctor);
      expect(find.text('Descendente'), findsOneWidget);
      expect(_rows(tester).first[_doctor], 'Esteban Silva');

      await clear(tester);

      expect(selected<ShiftOrder>(tester, 'filter-order'), ShiftOrder.date);
      expect(find.text('Ascendente'), findsOneWidget);
      expect(find.text('Descendente'), findsNothing);
      expect(_rows(tester).first[_date], '19/10/2026');
    });

    testWidgets('vuelve a la página 1', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 2 · 32 turnos'), findsOneWidget);

      await clear(tester);

      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('aplica la búsqueda al instante, sin apretar "Buscar"', (
      tester,
    ) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-doctor'), 'Carla Méndez');
      await _apply(tester);
      expect(_rows(tester), hasLength(4));

      await clear(tester);

      expect(_rows(tester), hasLength(20));
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('descarta lo elegido que todavía no se había aplicado', (
      tester,
    ) async {
      await _pump(tester);
      await _choose(tester, const Key('filter-state'), 'Suspendida');
      // Elegido pero sin "Buscar": la lista sigue completa.
      expect(selected<ShiftState?>(tester, 'filter-state'), isNotNull);
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);

      await clear(tester);
      expect(selected<ShiftState?>(tester, 'filter-state'), isNull);

      // Y si se busca ahora, no queda nada de lo elegido antes.
      await _apply(tester);
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
    });

    testWidgets('limpia el error de rango', (tester) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '01/11/2026');
      await _typeDate(tester, 'Hasta', '01/10/2026');
      await _apply(tester);
      const rangeMessage =
          'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';
      expect(find.text(rangeMessage), findsOneWidget);

      await clear(tester);

      expect(find.text(rangeMessage), findsNothing);
    });

    testWidgets('limpia un error de formato que se estaba viendo', (
      tester,
    ) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '31/02/2026');
      // Primero: el error está a la vista.
      expect(find.text(_nonexistentDate), findsOneWidget);

      await clear(tester);

      expect(find.text(_nonexistentDate), findsNothing);
      expect(find.text(_badDateFormat), findsNothing);
      expect(_fieldText(tester, 'Desde'), isEmpty);
    });

    testWidgets('suelta el foco del campo de fecha', (tester) async {
      await _pump(tester);
      await _typeDate(tester, 'Desde', '20/10');
      expect(anyDateFieldFocused(tester), isTrue);

      await clear(tester);

      expect(anyDateFieldFocused(tester), isFalse);
    });

    testWidgets('desde una búsqueda sin resultados vuelve a mostrar todo', (
      tester,
    ) async {
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

      await clear(tester);

      expect(find.byType(DataTable), findsOneWidget);
      expect(_rows(tester), hasLength(20));
      expect(find.textContaining('No se encontraron turnos'), findsNothing);
    });

    testWidgets('con todo ya limpio no cambia nada ni falla', (tester) async {
      await _pump(tester);

      await clear(tester);

      expect(tester.takeException(), isNull);
      expect(_rows(tester), hasLength(20));
      expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);
      expect(find.text(_badDateFormat), findsNothing);
      expect(find.text(_nonexistentDate), findsNothing);
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

  testWidgets('cada fila enlaza a su configuración', (tester) async {
    final admin = FakeAdminDatabase();
    final shiftDb = buildListingDb(admin);
    final page = shiftDb.listShifts(const ShiftFilters());
    final router = await pumpAdminScreens(
      tester,
      size: _wideScreen,
      initialLocation: kShiftsPath,
      routes: [
        GoRoute(path: kShiftsPath, builder: (_, _) => const ShiftsScreen()),
        GoRoute(
          path: kWeeklyShiftDetailPath,
          builder: (_, state) =>
              Scaffold(body: Text('Detalle ${state.pathParameters['id']}')),
        ),
      ],
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(shiftDb, latency: Duration.zero),
        ),
        specialtyRepositoryProvider.overrideWith(
          (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
        ),
      ],
    );

    for (final shift in page.items) {
      expect(find.byKey(Key('shift-config-link-${shift.id}')), findsOneWidget);
    }
    final first = page.items.first;
    expect(first.weeklyShiftId, isNot(first.id));
    final link = find.byKey(Key('shift-config-link-${first.id}'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(
      currentLocation(router),
      weeklyShiftDetailLocation(first.weeklyShiftId),
    );
  });

  testWidgets('con 700 px la tarjeta abre la configuración', (tester) async {
    final admin = FakeAdminDatabase();
    final shiftDb = buildListingDb(admin);
    final page = shiftDb.listShifts(const ShiftFilters());
    final router = await pumpAdminScreens(
      tester,
      size: const Size(700, 1800),
      initialLocation: kShiftsPath,
      routes: [
        GoRoute(path: kShiftsPath, builder: (_, _) => const ShiftsScreen()),
        GoRoute(
          path: kWeeklyShiftDetailPath,
          builder: (_, state) =>
              Scaffold(body: Text('Detalle ${state.pathParameters['id']}')),
        ),
      ],
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(shiftDb, latency: Duration.zero),
        ),
        specialtyRepositoryProvider.overrideWith(
          (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
        ),
      ],
    );

    final first = page.items.first;
    expect(first.weeklyShiftId, isNot(first.id));
    final link = find.byKey(Key('shift-config-link-${first.id}'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(
      currentLocation(router),
      weeklyShiftDetailLocation(first.weeklyShiftId),
    );
  });

  testWidgets('con 700 px la tarjeta dice Ver configuración', (tester) async {
    final admin = FakeAdminDatabase();
    final shiftDb = buildListingDb(admin);
    final page = shiftDb.listShifts(const ShiftFilters());
    await pumpAdminScreens(
      tester,
      size: const Size(700, 1800),
      initialLocation: kShiftsPath,
      routes: [
        GoRoute(path: kShiftsPath, builder: (_, _) => const ShiftsScreen()),
      ],
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(shiftDb, latency: Duration.zero),
        ),
        specialtyRepositoryProvider.overrideWith(
          (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
        ),
      ],
    );

    expect(find.text('Ver configuración'), findsNWidgets(20));
    expect(
      find.byKey(Key('shift-config-link-${page.items.first.id}')),
      findsOneWidget,
    );
  });
}
