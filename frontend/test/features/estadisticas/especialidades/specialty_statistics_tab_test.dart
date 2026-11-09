import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/models/specialty_demand.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/providers/specialty_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/repositories/specialty_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/specialty_statistics_tab.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

typedef _Call = ({DateTime? from, DateTime? to});

SpecialtyDemandItem _item(int id, String name, bool referral, int count) =>
    SpecialtyDemandItem(
      specialty: Specialty(id: id, name: name, requiresReferral: referral),
      count: count,
    );

SpecialtyDemand _demand({List<SpecialtyDemandItem>? items}) => SpecialtyDemand(
  from: DateTime.utc(2026, 10, 1),
  to: DateTime.utc(2026, 10, 31),
  items:
      items ??
      [
        _item(1, 'Medicina General', false, 128),
        _item(3, 'Cardiología', true, 42),
        _item(4, 'Dermatología', true, 7),
        _item(2, 'Pediatría', false, 0),
      ],
);

class _Repository implements SpecialtyStatisticsRepository {
  _Repository([this.responder]);

  Future<SpecialtyDemand> Function(_Call call)? responder;
  final calls = <_Call>[];

  @override
  Future<SpecialtyDemand> demand({DateTime? from, DateTime? to}) {
    final call = (from: from, to: to);
    calls.add(call);
    return responder?.call(call) ?? Future.value(_demand());
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(800, 2000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        specialtyStatisticsRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: SpecialtyStatisticsTab())),
    ),
  );
}

String _fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

Future<void> _consult(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('stats-consult')));
  await tester.pumpAndSettle();
}

/// El aviso de error: el propio `Text` lleva la key `stats-error`.
Finder _errorWith(String message) => find.byWidgetPredicate(
  (w) => w is Text && w.key == const Key('stats-error') && w.data == message,
);

Finder _inRow(int index, String text) => find.descendant(
  of: find.byKey(Key('stats-row-$index')),
  matching: find.text(text),
);

void main() {
  setUpAll(loadRoboto);

  testWidgets(
    'al abrir consulta una vez sin parámetros y muestra el cargando',
    (tester) async {
      final completer = Completer<SpecialtyDemand>();
      final repository = _Repository((_) => completer.future);
      await _pump(tester, repository);
      await tester.pump();

      expect(find.byKey(const Key('stats-loading')), findsOneWidget);
      expect(find.text('Calculando estadísticas'), findsOneWidget);
      expect(repository.calls, hasLength(1));
      expect(repository.calls.single, (from: null, to: null));

      completer.complete(_demand());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-loading')), findsNothing);
      expect(repository.calls, hasLength(1));
    },
  );

  testWidgets('tras cargar muestra el período de los datos', (tester) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
  });

  testWidgets('editar Desde sin consultar no cambia el texto del período', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '01/01/2026');

    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
    expect(find.text('Total de consultas: 177'), findsOneWidget);
  });

  testWidgets('Consultar con otro Desde cambia el texto a la respuesta', (
    tester,
  ) async {
    final repository = _Repository(
      (call) async => SpecialtyDemand(
        from: call.from ?? DateTime.utc(2026, 10, 1),
        to: call.to ?? DateTime.utc(2026, 10, 31),
        items: _demand().items,
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
    await _consult(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 05/10/2026 al 31/10/2026',
    );
  });

  testWidgets('mientras carga no muestra el texto', (tester) async {
    final completer = Completer<SpecialtyDemand>();
    final repository = _Repository((_) => completer.future);
    await _pump(tester, repository);
    await tester.pump();

    expect(find.byKey(const Key('stats-period-label')), findsNothing);

    completer.complete(_demand());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-period-label')), findsOneWidget);
  });

  testWidgets('si hay error no muestra el texto', (tester) async {
    final repository = _Repository((_) async => throw const ApiException());
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-period-label')), findsNothing);
    expect(find.byKey(const Key('stats-error')), findsOneWidget);
  });

  testWidgets('con la lista vacía igual muestra el período', (tester) async {
    await _pump(tester, _Repository((_) async => _demand(items: const [])));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
  });

  testWidgets('muestra las filas en el orden del servidor y el total', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    expect(_inRow(0, 'Medicina General'), findsOneWidget);
    expect(_inRow(0, '128'), findsOneWidget);
    expect(_inRow(1, 'Cardiología'), findsOneWidget);
    expect(_inRow(1, '42'), findsOneWidget);
    expect(_inRow(2, 'Dermatología'), findsOneWidget);
    expect(_inRow(2, '7'), findsOneWidget);
    expect(_inRow(3, 'Pediatría'), findsOneWidget);
    expect(_inRow(3, '0'), findsOneWidget);
    expect(find.byKey(const Key('stats-row-4')), findsNothing);
    expect(find.text('Total de consultas: 177'), findsOneWidget);
  });

  testWidgets('el gráfico tiene una barra por especialidad con su cantidad', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    final groups = tester
        .widget<BarChart>(find.byType(BarChart))
        .data
        .barGroups;

    expect(groups, hasLength(4));
    expect(groups.map((g) => g.barRods.single.toY), [128, 42, 7, 0]);
  });

  testWidgets('Requiere pase aparece solo en Cardiología y Dermatología', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    expect(_inRow(0, 'Requiere pase'), findsNothing);
    expect(_inRow(1, 'Requiere pase'), findsOneWidget);
    expect(_inRow(2, 'Requiere pase'), findsOneWidget);
    expect(_inRow(3, 'Requiere pase'), findsNothing);
  });

  testWidgets('llena Desde y Hasta con la respuesta y muestra el texto', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'stats-from'), '01/10/2026');
    expect(_fieldText(tester, 'stats-to'), '31/10/2026');
    expect(find.text('Por defecto: mes en curso'), findsOneWidget);
  });

  testWidgets('Consultar sin tocar las fechas pide otra vez sin parámetros', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await _consult(tester);

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last, (from: null, to: null));
  });

  testWidgets('cambiar una fecha no consulta sola', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
  });

  testWidgets('elegir solo Desde y consultar manda solo desde', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
    await _consult(tester);

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last, (from: DateTime.utc(2026, 10, 5), to: null));
  });

  testWidgets('Desde posterior a Hasta muestra el error y no consulta', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '20/10/2026');
    await tester.enterText(find.byKey(const Key('stats-to')), '05/10/2026');
    await _consult(tester);

    expect(find.byKey(const Key('stats-period-error')), findsOneWidget);
    expect(
      find.text('La fecha Desde no puede ser posterior a la fecha Hasta.'),
      findsOneWidget,
    );
    expect(repository.calls, hasLength(1));
  });

  testWidgets('sin filas muestra el aviso de que no hay consultas', (
    tester,
  ) async {
    final repository = _Repository((_) async => _demand(items: const []));
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-empty')), findsOneWidget);
    expect(find.text('No hay consultas en el período.'), findsOneWidget);
    expect(find.text('Total de consultas: 0'), findsOneWidget);
  });

  group('errores', () {
    testWidgets('un 400 muestra el mensaje del servidor', (tester) async {
      final repository = _Repository(
        (_) async => throw const SpecialtyStatisticsException(
          SpecialtyStatisticsFailure.validation,
          'desde debe tener formato YYYY-MM-DD',
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_errorWith('desde debe tener formato YYYY-MM-DD'), findsOneWidget);
    });

    testWidgets('un 401 pide iniciar sesión nuevamente', (tester) async {
      final repository = _Repository(
        (_) async => throw const SpecialtyStatisticsException(
          SpecialtyStatisticsFailure.unauthenticated,
          'Sesión vencida',
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(
        _errorWith('Tu sesión venció. Iniciá sesión nuevamente.'),
        findsOneWidget,
      );
    });

    testWidgets('un 403 avisa que falta permiso', (tester) async {
      final repository = _Repository(
        (_) async => throw const SpecialtyStatisticsException(
          SpecialtyStatisticsFailure.forbidden,
          'Sin permiso',
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(
        _errorWith('Tu cuenta no tiene permiso para ver las estadísticas.'),
        findsOneWidget,
      );
    });

    testWidgets('cualquier otro error muestra el mensaje genérico', (
      tester,
    ) async {
      final repository = _Repository((_) async => throw const ApiException());
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_errorWith(kApiGenericMessage), findsOneWidget);
    });

    testWidgets('Reintentar repite la consulta fallida con sus parámetros', (
      tester,
    ) async {
      var fail = false;
      final repository = _Repository((_) async {
        if (fail) {
          throw const SpecialtyStatisticsException(
            SpecialtyStatisticsFailure.validation,
            'Fechas inválidas',
          );
        }
        return _demand();
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      fail = true;
      await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
      await _consult(tester);
      expect(find.byKey(const Key('stats-error')), findsOneWidget);
      expect(repository.calls, hasLength(2));

      fail = false;
      await tester.tap(find.byKey(const Key('stats-retry')));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(3));
      expect(repository.calls.last, (
        from: DateTime.utc(2026, 10, 5),
        to: null,
      ));
      expect(find.byKey(const Key('stats-error')), findsNothing);
      expect(find.text('Total de consultas: 177'), findsOneWidget);
    });

    testWidgets('Reintentar tras un fallo inicial pide sin parámetros', (
      tester,
    ) async {
      var fail = true;
      final repository = _Repository((_) async {
        if (fail) throw const ApiException();
        return _demand();
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      fail = false;
      await tester.tap(find.byKey(const Key('stats-retry')));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(2));
      expect(repository.calls.last, (from: null, to: null));
      expect(find.text('Total de consultas: 177'), findsOneWidget);
    });
  });

  testWidgets('a 320 px de ancho no hay desbordes', (tester) async {
    await _pump(tester, _Repository(), size: const Size(320, 700));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Total de consultas: 177'), findsOneWidget);
    expect(find.byKey(const Key('stats-period-label')), findsOneWidget);
  });
}
