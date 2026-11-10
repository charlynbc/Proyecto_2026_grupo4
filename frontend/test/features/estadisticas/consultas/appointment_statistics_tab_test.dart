import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/estadisticas/consultas/models/appointment_statistics.dart';
import 'package:agenda_medica/features/estadisticas/consultas/providers/appointment_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/consultas/repositories/appointment_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/consultas/repositories/fake_appointment_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/appointment_statistics_tab.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';
import 'appointment_statistics_fixtures.dart';

typedef _Call = ({DateTime? from, DateTime? to});

class _Repository implements AppointmentStatisticsRepository {
  _Repository([this.responder]);

  Future<AppointmentStatistics> Function(_Call call)? responder;
  final calls = <_Call>[];

  @override
  Future<AppointmentStatistics> statistics({DateTime? from, DateTime? to}) {
    final call = (from: from, to: to);
    calls.add(call);
    return responder?.call(call) ?? Future.value(statisticsOf());
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppointmentStatisticsRepository repository, {
  Size size = const Size(900, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentStatisticsRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AppointmentStatisticsTab()),
      ),
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

Finder _row(int index) => find.byKey(Key('stats-state-row-$index'));

Finder _in(Finder container, String text) =>
    find.descendant(of: container, matching: find.text(text));

String _textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

List<double> _barHeights(WidgetTester tester) => tester
    .widget<BarChart>(find.byType(BarChart))
    .data
    .barGroups
    .map((g) => g.barRods.single.toY)
    .toList();

void main() {
  setUpAll(loadRoboto);

  testWidgets(
    'al abrir consulta una vez sin parámetros y muestra el cargando',
    (tester) async {
      final completer = Completer<AppointmentStatistics>();
      final repository = _Repository((_) => completer.future);
      await _pump(tester, repository);
      await tester.pump();

      expect(find.byKey(const Key('stats-loading')), findsOneWidget);
      expect(find.text('Calculando estadísticas'), findsOneWidget);
      expect(repository.calls, hasLength(1));
      expect(repository.calls.single, (from: null, to: null));

      completer.complete(statisticsOf());
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

  testWidgets('el texto del período sigue siendo el de los datos tras un rebuild', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '20/10/2026');
    await tester.enterText(find.byKey(const Key('stats-to')), '05/10/2026');
    await _consult(tester);

    expect(find.byKey(const Key('stats-period-error')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
  });

  testWidgets('mientras una nueva consulta carga no muestra el texto', (
    tester,
  ) async {
    final completer = Completer<AppointmentStatistics>();
    var calls = 0;
    final repository = _Repository((_) {
      if (calls++ == 0) return Future.value(statisticsOf());
      return completer.future;
    });
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-period-label')), findsOneWidget);

    await tester.tap(find.byKey(const Key('stats-consult')));
    await tester.pump();

    expect(find.byKey(const Key('stats-loading')), findsOneWidget);
    expect(find.byKey(const Key('stats-period-label')), findsNothing);

    completer.complete(statisticsOf());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-period-label')), findsOneWidget);
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
  });

  testWidgets('Consultar con otro Desde cambia el texto a la respuesta', (
    tester,
  ) async {
    final repository = _Repository((call) async {
      final response = statisticsOf();
      return AppointmentStatistics(
        from: call.from ?? DateTime.utc(2026, 10, 1),
        to: call.to ?? DateTime.utc(2026, 10, 31),
        counts: response.counts,
        total: response.total,
        cancelledBySocio: response.cancelledBySocio,
        percentage: response.percentage,
        percentageText: response.percentageText,
      );
    });
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
    final completer = Completer<AppointmentStatistics>();
    final repository = _Repository((_) => completer.future);
    await _pump(tester, repository);
    await tester.pump();

    expect(find.byKey(const Key('stats-period-label')), findsNothing);

    completer.complete(statisticsOf());
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

  group('tarjetas', () {
    testWidgets('muestran el total y la tasa del servidor', (tester) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      expect(
        find.text('Consultas del período (por fecha de consulta)'),
        findsOneWidget,
      );
      expect(find.text('Tasa de cancelación por el socio'), findsOneWidget);
      expect(_textOf(tester, 'stats-total-value'), '200');
      expect(_textOf(tester, 'stats-rate-value'), '10 %');
    });

    testWidgets('el subtítulo de la tasa dice cuántas de cuántas', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      expect(_textOf(tester, 'stats-rate-subtitle'), '20 de 200 consultas');
      expect(find.text('20 de 200 consultas'), findsOneWidget);
      expect(find.text('Sin datos si el total es cero'), findsNothing);
    });

    testWidgets('el total es el que manda el servidor, no la suma', (
      tester,
    ) async {
      final repository = _Repository((_) async => statisticsOf(total: 201));
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_textOf(tester, 'stats-total-value'), '201');
    });

    testWidgets('el subtítulo usa el total del servidor, no la suma', (
      tester,
    ) async {
      final repository = _Repository((_) async => statisticsOf(total: 201));
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_textOf(tester, 'stats-rate-subtitle'), '20 de 201 consultas');
    });

    testWidgets('el subtítulo usa las canceladas por el socio del servidor', (
      tester,
    ) async {
      final repository = _Repository(
        (_) async => statisticsOf(cancelled: 7, total: 90),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_textOf(tester, 'stats-rate-subtitle'), '7 de 90 consultas');
    });

    testWidgets('el texto de la tasa se muestra tal cual', (tester) async {
      final repository = _Repository(
        (_) async => statisticsOf(percentage: 9.38, percentageText: '9.38 %'),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_textOf(tester, 'stats-rate-value'), '9.38 %');
    });
  });

  group('lista y gráfico', () {
    testWidgets('la lista muestra los siete estados en el orden fijo', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      const counts = ['40', '110', '20', '8', '14', '5', '3'];
      for (var i = 0; i < 7; i++) {
        expect(_in(_row(i), statusLabels[i]), findsOneWidget, reason: '$i');
        expect(_in(_row(i), counts[i]), findsOneWidget, reason: '$i');
      }
      expect(_row(7), findsNothing);
      final tops = [for (var i = 0; i < 7; i++) tester.getTopLeft(_row(i)).dy];
      expect(tops, [...tops]..sort());
    });

    testWidgets('el gráfico tiene siete barras con las cantidades', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      expect(_barHeights(tester), [40, 110, 20, 8, 14, 5, 3]);
    });

    testWidgets('con total cero muestra todo en cero y el gráfico sigue', (
      tester,
    ) async {
      final repository = FakeAppointmentStatisticsRepository(
        latency: Duration.zero,
        clock: () => DateTime.utc(2026, 10, 14, 15),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
      await tester.enterText(find.byKey(const Key('stats-to')), '05/10/2026');
      await _consult(tester);

      expect(_textOf(tester, 'stats-total-value'), '0');
      expect(_textOf(tester, 'stats-rate-value'), 'Sin datos');
      expect(_textOf(tester, 'stats-rate-subtitle'), '0 de 0 consultas');
      expect(_barHeights(tester), [0, 0, 0, 0, 0, 0, 0]);
      expect(
        tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
        'Datos del 05/10/2026 al 05/10/2026',
      );
      for (var i = 0; i < 7; i++) {
        expect(_in(_row(i), '0'), findsOneWidget, reason: '$i');
      }
    });
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

  group('errores', () {
    testWidgets('un 400 muestra el mensaje del servidor', (tester) async {
      final repository = _Repository(
        (_) async => throw const AppointmentStatisticsException(
          AppointmentStatisticsFailure.validation,
          'desde debe tener formato YYYY-MM-DD',
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_errorWith('desde debe tener formato YYYY-MM-DD'), findsOneWidget);
    });

    testWidgets('un 401 pide iniciar sesión nuevamente', (tester) async {
      final repository = _Repository(
        (_) async => throw const AppointmentStatisticsException(
          AppointmentStatisticsFailure.unauthenticated,
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
        (_) async => throw const AppointmentStatisticsException(
          AppointmentStatisticsFailure.forbidden,
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
          throw const AppointmentStatisticsException(
            AppointmentStatisticsFailure.validation,
            'Fechas inválidas',
          );
        }
        return statisticsOf();
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
      expect(_textOf(tester, 'stats-total-value'), '200');
    });

    testWidgets('Reintentar tras un fallo inicial pide sin parámetros', (
      tester,
    ) async {
      var fail = true;
      final repository = _Repository((_) async {
        if (fail) throw const ApiException();
        return statisticsOf();
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      fail = false;
      await tester.tap(find.byKey(const Key('stats-retry')));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(2));
      expect(repository.calls.last, (from: null, to: null));
      expect(_textOf(tester, 'stats-total-value'), '200');
    });
  });

  testWidgets('a 320 px de ancho no hay desbordes', (tester) async {
    await _pump(tester, _Repository(), size: const Size(320, 2400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_textOf(tester, 'stats-total-value'), '200');
    expect(find.byKey(const Key('stats-chart-scroll-hint')), findsOneWidget);
    expect(find.byKey(const Key('stats-period-label')), findsOneWidget);
  });
}
