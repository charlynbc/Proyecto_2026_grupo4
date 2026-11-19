import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attention_repository_provider.dart';
import 'package:agenda_medica/features/medico/providers/doctor_attentions_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attentions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

const _rangeMessage =
    'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';
const _required = 'Ingresá la fecha.';
const _noExiste =
    'Esa fecha no existe en el calendario. Revisá el día y el mes.';

/// Los filtros de la pantalla con las fechas de un 12/11/2026 a las 10:00 en
/// Uruguay: del 01/11/2026 al 12/11/2026. La pantalla no tiene un reloj
/// inyectable (arma las fechas con `DoctorAttentionQuery.initial()`), así que
/// se fijan en el provider de los filtros, que es de donde las toma.
class _FixedFilters extends DoctorAttentionFiltersController {
  _FixedFilters({this.initial});
  final DoctorAttentionQuery? initial;
  static final fixed = DoctorAttentionQuery(
    from: DateTime.utc(2026, 11, 1),
    to: DateTime.utc(2026, 11, 12),
  );

  /// Lo que devuelve Limpiar: por defecto lo mismo; un test lo cambia para
  /// simular que el mes cambió entre abrir la pantalla y limpiar.
  static DoctorAttentionQuery afterClear = fixed;

  @override
  DoctorAttentionQuery build() => initial ?? fixed;

  @override
  void clear() => state = afterClear;
}

class _Repository implements DoctorAttentionRepository {
  final queries = <DoctorAttentionQuery>[];

  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async {
    queries.add(query);
    return const [];
  }

  @override
  Future<DoctorAttention> get(int id) => throw UnimplementedError();
}

Future<_Repository> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
  double textScale = 1,
  DoctorAttentionQuery? initial,
}) async {
  final repository = _Repository();
  _FixedFilters.afterClear = _FixedFilters.fixed;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorAttentionRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        doctorAttentionFiltersProvider.overrideWith(
          () => _FixedFilters(initial: initial),
        ),
        specialtiesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        locale: kAppLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const DoctorAttentionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

const _fromKey = Key('attentions-from');
const _toKey = Key('attentions-to');

Finder _input(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

String _text(WidgetTester tester, Key key) =>
    tester.widget<EditableText>(_input(key)).controller.text;

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(_input(key));
  await tester.pumpAndSettle();
  await tester.enterText(_input(key), text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _last(_Repository repository) =>
    repository.queries.last.toQueryParameters();

void main() {
  testWidgets('sin resultados muestra cero atenciones y el mensaje exacto', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('0 atenciones'), findsOneWidget);
    expect(
      find.text('No hay atenciones que coincidan con los filtros.'),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('attention-'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'al abrir refleja las fechas previamente aplicadas de otro período',
    (tester) async {
      final repo = await _pump(
        tester,
        initial: DoctorAttentionQuery(
          from: DateTime.utc(2025, 8, 5),
          to: DateTime.utc(2025, 8, 20),
        ),
      );
      expect(_text(tester, _fromKey), '05/08/2025');
      expect(_text(tester, _toKey), '20/08/2025');
      expect(_last(repo)['fechaDesde'], '2025-08-05');
      expect(_last(repo)['fechaHasta'], '2025-08-20');
    },
  );

  for (final (key, label) in [(_fromKey, 'Desde'), (_toKey, 'Hasta')]) {
    testWidgets('Enter en $label no ejecuta Buscar', (tester) async {
      final repo = await _pump(tester);
      final before = repo.queries.length;
      await _type(tester, key, '06/11/2026');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.queries, hasLength(before));
      expect(_text(tester, key), '06/11/2026');
    });

    testWidgets('Buscar quita el foco de $label y aplica la fecha', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _type(tester, key, '06/11/2026');
      final field = tester.widget<EditableText>(_input(key));
      expect(field.focusNode.hasFocus, isTrue);
      final before = repo.queries.length;
      await _tap(tester, 'attentions-search');
      expect(field.focusNode.hasFocus, isFalse);
      expect(repo.queries, hasLength(before + 1));
      expect(
        _last(repo)[key == _fromKey ? 'fechaDesde' : 'fechaHasta'],
        '2026-11-06',
      );
    });
  }

  testWidgets('los calendarios de Desde y Hasta aplican las fechas al buscar', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final before = repo.queries.length;
    for (final (tooltip, day) in [
      ('Elegir la fecha desde', '5'),
      ('Elegir la fecha hasta', '10'),
    ]) {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      final calendar = find.byType(CalendarDatePicker);
      expect(calendar, findsOneWidget);
      await tester.tap(find.descendant(of: calendar, matching: find.text(day)));
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
    }
    expect(_text(tester, _fromKey), '05/11/2026');
    expect(_text(tester, _toKey), '10/11/2026');
    expect(repo.queries, hasLength(before));
    await _tap(tester, 'attentions-search');
    expect(repo.queries, hasLength(before + 1));
    expect(_last(repo)['fechaDesde'], '2026-11-05');
    expect(_last(repo)['fechaHasta'], '2026-11-10');
  });

  testWidgets('Hasta vacía abre en Desde y una Hasta válida tiene prioridad', (
    tester,
  ) async {
    await _pump(tester);
    await _type(tester, _fromKey, '05/11/2026');
    await _type(tester, _toKey, '');
    await tester.tap(find.byTooltip('Elegir la fecha hasta'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .initialDate,
      DateTime(2026, 11, 5),
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(_text(tester, _toKey), '05/11/2026');
    await _type(tester, _toKey, '10/11/2026');
    await tester.tap(find.byTooltip('Elegir la fecha hasta'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .initialDate,
      DateTime(2026, 11, 10),
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  for (final (key, tooltip, outside, expected, date) in [
    (
      _fromKey,
      'Elegir la fecha desde',
      '31/12/1899',
      '01/01/1900',
      DateTime(1900),
    ),
    (
      _toKey,
      'Elegir la fecha hasta',
      '02/01/2100',
      '01/01/2100',
      DateTime(2100),
    ),
  ]) {
    testWidgets('el calendario respeta el límite $expected', (tester) async {
      await _pump(tester);
      await _type(tester, key, outside);
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      final calendar = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(calendar.firstDate, DateTime(1900));
      expect(calendar.lastDate, DateTime(2100));
      expect(calendar.initialDate, date);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(_text(tester, key), expected);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('al abrir muestra 01/11/2026 y 12/11/2026', (tester) async {
    await _pump(tester);

    expect(_text(tester, _fromKey), '01/11/2026');
    expect(_text(tester, _toKey), '12/11/2026');
  });

  testWidgets('Buscar sin tocar nada manda 2026-11-01 y 2026-11-12', (
    tester,
  ) async {
    final repository = await _pump(tester);

    await _tap(tester, 'attentions-search');

    expect(_last(repository)['fechaDesde'], '2026-11-01');
    expect(_last(repository)['fechaHasta'], '2026-11-12');
  });

  testWidgets('Desde 05/11/2026 y Hasta 10/11/2026 mandan 2026-11-05 y '
      '2026-11-10', (tester) async {
    final repository = await _pump(tester);
    await _type(tester, _fromKey, '05/11/2026');
    await _type(tester, _toKey, '10/11/2026');

    await _tap(tester, 'attentions-search');

    expect(_last(repository)['fechaDesde'], '2026-11-05');
    expect(_last(repository)['fechaHasta'], '2026-11-10');
  });

  testWidgets('escribir en un campo no busca hasta tocar Buscar', (
    tester,
  ) async {
    final repository = await _pump(tester);
    final before = repository.queries.length;

    await _type(tester, _fromKey, '05/11/2026');
    await _type(tester, _toKey, '10/11/2026');

    expect(repository.queries, hasLength(before));
  });

  testWidgets('Desde posterior a Hasta: no busca y avisa en el campo Hasta', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await _type(tester, _fromKey, '15/11/2026');
    final before = repository.queries.length;

    await _tap(tester, 'attentions-search');

    expect(repository.queries, hasLength(before));
    expect(
      find.descendant(
        of: find.byKey(_toKey),
        matching: find.text(_rangeMessage),
      ),
      findsOneWidget,
    );
    expect(find.text(_rangeMessage), findsOneWidget);
  });

  for (final (name, key) in [('Desde', _fromKey), ('Hasta', _toKey)]) {
    testWidgets('al cambiar $name el aviso del rango desaparece', (
      tester,
    ) async {
      await _pump(tester);
      await _type(tester, _fromKey, '15/11/2026');
      await _tap(tester, 'attentions-search');
      expect(find.text(_rangeMessage), findsOneWidget);

      await _type(tester, key, key == _fromKey ? '10/11/2026' : '20/11/2026');

      expect(find.text(_rangeMessage), findsNothing);
    });
  }

  for (final (name, key) in [('Desde', _fromKey), ('Hasta', _toKey)]) {
    testWidgets('$name vacío: no busca y pide la fecha', (tester) async {
      final repository = await _pump(tester);
      await _type(tester, key, '');
      final before = repository.queries.length;

      await _tap(tester, 'attentions-search');

      expect(repository.queries, hasLength(before));
      expect(find.text(_required), findsOneWidget);
    });
  }

  testWidgets('una fecha que no existe en Desde: no busca y avisa', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await _type(tester, _fromKey, '31/02/2026');
    final before = repository.queries.length;

    await _tap(tester, 'attentions-search');

    expect(repository.queries, hasLength(before));
    expect(find.text(_noExiste), findsOneWidget);
  });

  testWidgets('Limpiar tras cambiar las dos fechas las deja en 01/11/2026 y '
      '12/11/2026', (tester) async {
    final repository = await _pump(tester);
    await _type(tester, _fromKey, '05/11/2026');
    await _type(tester, _toKey, '10/11/2026');
    await _tap(tester, 'attentions-search');

    await _tap(tester, 'attentions-clear');

    expect(_text(tester, _fromKey), '01/11/2026');
    expect(_text(tester, _toKey), '12/11/2026');
    expect(_last(repository)['fechaDesde'], '2026-11-01');
    expect(_last(repository)['fechaHasta'], '2026-11-12');
  });

  testWidgets('Limpiar muestra las fechas que el filtro devuelve al limpiar '
      '(si el mes cambió desde que se abrió la pantalla)', (tester) async {
    await _pump(tester);
    _FixedFilters.afterClear = DoctorAttentionQuery(
      from: DateTime.utc(2026, 12, 1),
      to: DateTime.utc(2026, 12, 2),
    );

    await _tap(tester, 'attentions-clear');

    expect(_text(tester, _fromKey), '01/12/2026');
    expect(_text(tester, _toKey), '02/12/2026');
  });

  testWidgets('Limpiar borra el aviso de rango', (tester) async {
    await _pump(tester);
    await _type(tester, _fromKey, '15/11/2026');
    await _tap(tester, 'attentions-search');
    expect(find.text(_rangeMessage), findsOneWidget);

    await _tap(tester, 'attentions-clear');

    expect(find.text(_rangeMessage), findsNothing);
  });

  testWidgets(
    'selector de orden completo a 320 px con texto x2 y en escritorio conserva filtros',
    (tester) async {
      await loadRoboto();
      final repository = await _pump(
        tester,
        size: const Size(320, 2400),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await _type(tester, _fromKey, '05/11/2026');
      await _type(tester, _toKey, '10/11/2026');
      final patient = find.byKey(const Key('attentions-patient-field'));
      await tester.ensureVisible(patient);
      await tester.enterText(patient, '4.567.891-1');
      await _tap(tester, 'attentions-search');
      final selector = find.byKey(const Key('attentions-order'));

      void expectCriteria(String order) {
        expect(_last(repository)['orden'], order);
        expect(_last(repository)['sentido'], 'desc');
        expect(_last(repository)['paciente'], '45678911');
        expect(_last(repository)['fechaDesde'], '2026-11-05');
        expect(_last(repository)['fechaHasta'], '2026-11-10');
        expect(_text(tester, _fromKey), '05/11/2026');
        expect(_text(tester, _toKey), '10/11/2026');
        expect(
          tester.widget<TextField>(patient).controller!.text,
          '4.567.891-1',
        );
      }

      void expectCompleteText(Finder text, double width) {
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse);
        // Además de no truncar líneas, el texto debe caber en su opción
        // y en la pantalla: no basta con encontrar el Text en el árbol.
        final item = find.ancestor(
          of: text,
          matching: find.byType(DropdownMenuItem<DoctorAttentionOrder>),
        );
        expect(item, findsOneWidget);
        final textRect = tester.getRect(text);
        final itemRect = tester.getRect(item);
        expect(textRect.left, greaterThanOrEqualTo(itemRect.left - 1));
        expect(textRect.right, lessThanOrEqualTo(itemRect.right + 1));
        expect(textRect.top, greaterThanOrEqualTo(itemRect.top - 1));
        expect(textRect.bottom, lessThanOrEqualTo(itemRect.bottom + 1));
        expect(textRect.left, greaterThanOrEqualTo(0));
        expect(textRect.right, lessThanOrEqualTo(width));
        expect(textRect.top, greaterThanOrEqualTo(0));
        expect(textRect.bottom, lessThanOrEqualTo(2400));
      }

      expectCriteria('fecha');
      // Se redimensiona la misma pantalla, sin reconstruir la sesión ni
      // reiniciar los filtros. También se conserva texto x2 en escritorio.
      for (final width in [320.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 2400);
        await tester.pumpAndSettle();
        await tester.ensureVisible(selector);
        await tester.pumpAndSettle();
        expect(selector.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        final selectorRect = tester.getRect(selector);
        expect(selectorRect.left, greaterThanOrEqualTo(0));
        expect(selectorRect.right, lessThanOrEqualTo(width));
        if (width == 1200) {
          final directionRect = tester.getRect(
            find.byKey(const Key('attentions-direction')),
          );
          expect(selectorRect.right, lessThanOrEqualTo(directionRect.left));
          expect(selectorRect.center.dy, closeTo(directionRect.center.dy, 1));
        }

        for (final (label, value, parameter) in [
          (
            'Apellido del paciente',
            DoctorAttentionOrder.patientLastName,
            'apellido',
          ),
          ('Fecha', DoctorAttentionOrder.date, 'fecha'),
        ]) {
          final before = repository.queries.length;
          await _tap(tester, 'attentions-order');
          expect(tester.takeException(), isNull);
          // hitTestable excluye los textos del botón que queda bajo la
          // barrera modal: se inspeccionan las opciones del menú abierto.
          expectCompleteText(find.text('Fecha').hitTestable(), width);
          expectCompleteText(
            find.text('Apellido del paciente').hitTestable(),
            width,
          );
          await tester.tap(find.text(label).hitTestable());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<DropdownButton<DoctorAttentionOrder>>(selector).value,
            value,
          );
          expect(repository.queries.length, before + 1);
          expectCriteria(parameter);
          expectCompleteText(
            find
                .descendant(of: selector, matching: find.text(label))
                .hitTestable(),
            width,
          );
        }
      }
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('a 320 px con texto x$scale no desborda y las etiquetas '
        'Desde y Hasta no se cortan', (tester) async {
      await loadRoboto();
      await _pump(tester, size: const Size(320, 2400), textScale: scale);

      expect(tester.takeException(), isNull);
      for (final (key, label) in [(_fromKey, 'Desde'), (_toKey, 'Hasta')]) {
        final text = find.descendant(
          of: find.byKey(key),
          matching: find.text(label),
        );
        expect(text, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
          reason: label,
        );
      }
      final fromRect = tester.getRect(find.byKey(_fromKey));
      final toRect = tester.getRect(find.byKey(_toKey));
      expect(toRect.top, greaterThan(fromRect.bottom - 1));
      // 320 menos el relleno de 16 + 16 de la pantalla.
      expect(fromRect.width, closeTo(288, 1));
    });
  }
}
