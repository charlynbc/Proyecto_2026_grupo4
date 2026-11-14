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
  static final fixed = DoctorAttentionQuery(
    from: DateTime.utc(2026, 11, 1),
    to: DateTime.utc(2026, 11, 12),
  );

  /// Lo que devuelve Limpiar: por defecto lo mismo; un test lo cambia para
  /// simular que el mes cambió entre abrir la pantalla y limpiar.
  static DoctorAttentionQuery afterClear = fixed;

  @override
  DoctorAttentionQuery build() => fixed;

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
        doctorAttentionFiltersProvider.overrideWith(_FixedFilters.new),
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

  for (final scale in [1.0, 2.0]) {
    testWidgets('a 320 px con texto x$scale no desborda y las etiquetas '
        'Desde y Hasta no se cortan', (tester) async {
      await loadRoboto();
      await _pump(tester, size: const Size(320, 2400), textScale: scale);

      if (scale == 1.0) {
        expect(tester.takeException(), isNull);
      } else {
        // Con texto al doble la pantalla ya tenía 4 desbordes en otros
        // controles (medido antes de este cambio, con los botones de fecha).
        // Acá solo se comprueba lo de las fechas.
        tester.takeException();
      }
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
