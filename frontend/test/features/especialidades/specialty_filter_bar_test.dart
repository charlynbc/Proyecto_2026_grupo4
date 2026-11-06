import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/widgets/specialty_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class _Callbacks {
  final List<SpecialtyFilters> searches = [];
  final List<(SpecialtyOrder, bool)> sorts = [];
  int clears = 0;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<_Callbacks> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 900),
}) async {
  final callbacks = _Callbacks();
  var order = SpecialtyOrder.name;
  var ascending = true;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setState) => SpecialtyFilterBar(
              order: order,
              ascending: ascending,
              onSort: (selectedOrder, selectedAscending) {
                callbacks.sorts.add((selectedOrder, selectedAscending));
                setState(() {
                  order = selectedOrder;
                  ascending = selectedAscending;
                });
              },
              onSearch: callbacks.searches.add,
              onClear: () {
                callbacks.clears++;
                setState(() {
                  order = SpecialtyOrder.name;
                  ascending = true;
                });
              },
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return callbacks;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

/// Identifica las opciones abiertas por la estructura real de Flutter.
Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, key);
  final menuItem = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.role == SemanticsRole.menuItem,
    ),
  );
  expect(menuItem, findsOneWidget);
  final option = find
      .descendant(of: menuItem, matching: find.byType(InkWell))
      .hitTestable();
  expect(option, findsOneWidget);
  await tester.tap(option);
  await tester.pump();
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  testWidgets('cambiar orden comunica la selección inmediatamente sin Buscar', (
    tester,
  ) async {
    final callbacks = await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('specialty-filter-name')),
      'cardio',
    );
    await _select(tester, 'specialty-filter-referral', 'Sí');
    expect(callbacks.sorts, isEmpty);

    await _select(tester, 'specialty-filter-order', 'Fecha de alta');

    expect(callbacks.sorts, [(SpecialtyOrder.createdAt, true)]);
    expect(callbacks.searches, isEmpty);
    expect(callbacks.clears, 0);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('specialty-filter-name')))
          .controller!
          .text,
      'cardio',
    );
  });

  testWidgets('el sentido alterna texto e icono sin Buscar ni Limpiar', (
    tester,
  ) async {
    final callbacks = await _pump(tester);
    final direction = find.byKey(const Key('specialty-filter-direction'));
    expect(direction, findsOneWidget);
    expect(
      find.descendant(of: direction, matching: find.text('Ascendente')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: direction, matching: find.byIcon(Icons.arrow_upward)),
      findsOneWidget,
    );

    await _tap(tester, 'specialty-filter-direction');
    expect(callbacks.sorts, [(SpecialtyOrder.name, false)]);
    expect(
      find.descendant(of: direction, matching: find.text('Descendente')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: direction,
        matching: find.byIcon(Icons.arrow_downward),
      ),
      findsOneWidget,
    );

    await _tap(tester, 'specialty-filter-direction');
    expect(callbacks.sorts, [
      (SpecialtyOrder.name, false),
      (SpecialtyOrder.name, true),
    ]);
    expect(
      find.descendant(of: direction, matching: find.text('Ascendente')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: direction, matching: find.byIcon(Icons.arrow_upward)),
      findsOneWidget,
    );
    expect(callbacks.searches, isEmpty);
    expect(callbacks.clears, 0);
  });

  testWidgets('Buscar y cambiar criterio conservan el sentido seleccionado', (
    tester,
  ) async {
    final callbacks = await _pump(tester);
    await _tap(tester, 'specialty-filter-direction');
    await _select(tester, 'specialty-filter-order', 'Fecha de alta');
    expect(callbacks.sorts, [
      (SpecialtyOrder.name, false),
      (SpecialtyOrder.createdAt, false),
    ]);
    await tester.enterText(
      find.byKey(const Key('specialty-filter-name')),
      ' logía ',
    );
    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _tap(tester, 'specialty-filter-search');

    expect(callbacks.searches, hasLength(1));
    expect(callbacks.searches.single.name, 'logía');
    expect(callbacks.searches.single.requiresReferral, isTrue);
    expect(callbacks.searches.single.order, SpecialtyOrder.createdAt);
    expect(callbacks.searches.single.ascending, isFalse);
  });

  testWidgets(
    'Nombre tiene la clave requerida y admite como máximo 120 caracteres',
    (tester) async {
      await _pump(tester);
      final finder = find.byKey(const Key('specialty-filter-name'));
      final field = tester.widget<TextField>(
        find.descendant(of: finder, matching: find.byType(TextField)),
      );

      expect(field.decoration?.labelText, 'Nombre');
      expect(field.maxLength, 120);

      await tester.enterText(finder, List.filled(121, 'a').join());
      await tester.pump();
      expect(tester.widget<TextFormField>(finder).controller!.text.length, 120);
    },
  );

  testWidgets('Requiere pase ofrece Todas, Sí y No con valores correctos', (
    tester,
  ) async {
    final callbacks = await _pump(tester);
    final field = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('specialty-filter-referral')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(field.decoration.labelText, 'Requiere pase');
    expect(find.text('Todas'), findsOneWidget);

    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _tap(tester, 'specialty-filter-search');
    expect(callbacks.searches.last.requiresReferral, isTrue);

    await _select(tester, 'specialty-filter-referral', 'No');
    await _tap(tester, 'specialty-filter-search');
    expect(callbacks.searches.last.requiresReferral, isFalse);

    await _select(tester, 'specialty-filter-referral', 'Todas');
    await _tap(tester, 'specialty-filter-search');
    expect(callbacks.searches.last.requiresReferral, isNull);
    expect(callbacks.searches, hasLength(3));
  });

  testWidgets('Ordenar por ofrece Nombre y Fecha de alta', (tester) async {
    final callbacks = await _pump(tester);
    final field = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('specialty-filter-order')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(field.decoration.labelText, 'Ordenar por');

    await _select(tester, 'specialty-filter-order', 'Fecha de alta');
    await _tap(tester, 'specialty-filter-search');
    expect(callbacks.searches.last.order, SpecialtyOrder.createdAt);

    await _select(tester, 'specialty-filter-order', 'Nombre');
    await _tap(tester, 'specialty-filter-search');
    expect(callbacks.searches.last.order, SpecialtyOrder.name);
    expect(callbacks.searches, hasLength(2));
  });

  testWidgets(
    'Buscar tiene la clave requerida y entrega filtros predeterminados',
    (tester) async {
      final callbacks = await _pump(tester);
      final button = find.byKey(const Key('specialty-filter-search'));
      expect(
        find.descendant(of: button, matching: find.text('Buscar')),
        findsOneWidget,
      );

      await _tap(tester, 'specialty-filter-search');

      expect(callbacks.searches, hasLength(1));
      expect(callbacks.searches.single.toQueryParameters(), isEmpty);
      expect(callbacks.clears, 0);
    },
  );

  testWidgets(
    'Limpiar tiene la clave requerida y ejecuta su callback una vez',
    (tester) async {
      final callbacks = await _pump(tester);
      final button = find.byKey(const Key('specialty-filter-clear'));
      expect(
        find.descendant(of: button, matching: find.text('Limpiar')),
        findsOneWidget,
      );

      await _tap(tester, 'specialty-filter-clear');

      expect(callbacks.clears, 1);
      expect(callbacks.searches, isEmpty);
    },
  );

  testWidgets('editar nombre y desplegables no dispara Buscar ni Limpiar', (
    tester,
  ) async {
    final callbacks = await _pump(tester);
    expect(callbacks.searches, isEmpty);
    await tester.enterText(
      find.byKey(const Key('specialty-filter-name')),
      'cardio',
    );
    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _select(tester, 'specialty-filter-order', 'Fecha de alta');

    expect(callbacks.searches, isEmpty);
    expect(callbacks.clears, 0);
  });

  testWidgets(
    'Buscar entrega juntos los valores seleccionados y recorta el nombre',
    (tester) async {
      final callbacks = await _pump(tester);
      await tester.enterText(
        find.byKey(const Key('specialty-filter-name')),
        '  cardio  ',
      );
      await _select(tester, 'specialty-filter-referral', 'Sí');
      await _select(tester, 'specialty-filter-order', 'Fecha de alta');

      await _tap(tester, 'specialty-filter-search');

      expect(callbacks.searches, hasLength(1));
      final filters = callbacks.searches.single;
      expect(filters.name, 'cardio');
      expect(filters.requiresReferral, isTrue);
      expect(filters.order, SpecialtyOrder.createdAt);
      expect(callbacks.clears, 0);
    },
  );

  testWidgets(
    'Limpiar restablece todos los controles y la siguiente búsqueda',
    (tester) async {
      final callbacks = await _pump(tester);
      await tester.enterText(
        find.byKey(const Key('specialty-filter-name')),
        'cardio',
      );
      await _select(tester, 'specialty-filter-referral', 'No');
      await _select(tester, 'specialty-filter-order', 'Fecha de alta');
      await _tap(tester, 'specialty-filter-search');

      await _tap(tester, 'specialty-filter-direction');
      await _tap(tester, 'specialty-filter-clear');

      expect(callbacks.clears, 1);
      expect(callbacks.searches, hasLength(1));
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('specialty-filter-name')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .state<FormFieldState<bool>>(
              find.byKey(const Key('specialty-filter-referral')),
            )
            .value,
        isNull,
      );
      expect(
        tester
            .state<FormFieldState<SpecialtyOrder>>(
              find.byKey(const Key('specialty-filter-order')),
            )
            .value,
        SpecialtyOrder.name,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('specialty-filter-referral')),
          matching: find.text('Todas'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('specialty-filter-order')),
          matching: find.text('Nombre'),
        ),
        findsOneWidget,
      );

      await _tap(tester, 'specialty-filter-search');
      expect(callbacks.searches, hasLength(2));
      expect(callbacks.searches.last.toQueryParameters(), isEmpty);
      expect(callbacks.searches.last.ascending, isTrue);
      final direction = find.byKey(const Key('specialty-filter-direction'));
      expect(
        find.descendant(of: direction, matching: find.text('Ascendente')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: direction,
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Buscar trata un nombre de solo espacios como vacío', (
    tester,
  ) async {
    final callbacks = await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('specialty-filter-name')),
      '   ',
    );

    await _tap(tester, 'specialty-filter-search');

    expect(callbacks.searches, hasLength(1));
    expect(callbacks.searches.single.name ?? '', isEmpty);
    expect(callbacks.searches.single.toQueryParameters(), isEmpty);
  });

  testWidgets(
    'a 320 px con Roboto los controles son accesibles sin desbordes',
    (tester) async {
      await _pump(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      for (final key in [
        'specialty-filter-name',
        'specialty-filter-referral',
        'specialty-filter-order',
        'specialty-filter-direction',
        'specialty-filter-search',
        'specialty-filter-clear',
      ]) {
        final control = find.byKey(ValueKey(key));
        expect(control, findsOneWidget);
        await tester.ensureVisible(control);
        await _settle(tester);
        expect(control.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await _select(tester, 'specialty-filter-referral', 'Sí');
      await _select(tester, 'specialty-filter-order', 'Fecha de alta');
      await _tap(tester, 'specialty-filter-direction');
      expect(find.text('Descendente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
