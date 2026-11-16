import 'dart:async';

import 'package:agenda_medica/features/estadisticas/absences/models/absence_statistics.dart';
import 'package:agenda_medica/features/estadisticas/absences/providers/absence_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/absence_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/screens/statistics_screen.dart';
import 'package:agenda_medica/features/estadisticas/tabs/absence_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

typedef _Call = ({DateTime? from, DateTime? to, AbsenceGrouping grouping});

AbsenceGroup _specialty(
  String name,
  int id,
  int absences,
  int total,
  String text,
) {
  final attended = total - absences;
  return AbsenceGroup(
    id: id,
    name: name,
    lastName: null,
    attended: attended,
    noShow: absences,
    missed: 0,
    notAttended: 0,
    total: total,
    percentage: absences == 0 ? 0 : 12,
    percentageText: text,
  );
}

AbsenceStatistics _bySpecialty({
  DateTime? from,
  DateTime? to,
  List<AbsenceGroup>? items,
}) => AbsenceStatistics(
  from: from ?? DateTime.utc(2026, 10, 1),
  to: to ?? DateTime.utc(2026, 10, 31),
  groupedBy: 'ESPECIALIDAD',
  items:
      items ??
      [
        _specialty('Cardiología', 3, 3, 25, '12 %'),
        _specialty('Pediatría', 2, 0, 10, '0 %'),
      ],
);

AbsenceStatistics _byDoctor() => AbsenceStatistics(
  from: DateTime.utc(2026, 10, 1),
  to: DateTime.utc(2026, 10, 31),
  groupedBy: 'MEDICO',
  items: const [
    AbsenceGroup(
      id: 4,
      name: 'Carla',
      lastName: 'Méndez',
      attended: 6,
      noShow: 3,
      missed: 1,
      notAttended: 0,
      total: 10,
      percentage: 40,
      percentageText: '40 %',
    ),
  ],
);

class _Repository implements AbsenceStatisticsRepository {
  _Repository([this.responder]);

  Future<AbsenceStatistics> Function(_Call call)? responder;
  final calls = <_Call>[];

  @override
  Future<AbsenceStatistics> statistics({
    DateTime? from,
    DateTime? to,
    required AbsenceGrouping grouping,
  }) {
    final call = (from: from, to: to, grouping: grouping);
    calls.add(call);
    return responder?.call(call) ?? Future.value(_bySpecialty());
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(800, 2000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        absenceStatisticsRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: AbsenceStatisticsTab()),
      ),
    ),
  );
}

/// El texto buscado dentro de las tarjetas: el gráfico repite los nombres y
/// los porcentajes.
Finder _inCards(String text) =>
    find.descendant(of: find.byType(Card), matching: find.text(text));

/// Cuántas filas dibuja el gráfico.
int _tracks() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('absence-bar-track-'),
    )
    .evaluate()
    .length;

AbsenceGroup _percentGroup(
  int id,
  String name,
  String? lastName,
  int percentage,
) => AbsenceGroup(
  id: id,
  name: name,
  lastName: lastName,
  attended: 100 - percentage,
  noShow: percentage,
  missed: 0,
  notAttended: 0,
  total: 100,
  percentage: percentage.toDouble(),
  percentageText: '$percentage %',
);

/// Seis especialidades, de mayor a menor porcentaje.
AbsenceStatistics _specialties() => _bySpecialty(
  items: [
    _percentGroup(6, 'Traumatología', null, 40),
    _percentGroup(5, 'Oftalmología', null, 25),
    _percentGroup(3, 'Cardiología', null, 12),
    _percentGroup(4, 'Dermatología', null, 8),
    _percentGroup(1, 'Medicina General', null, 3),
    _percentGroup(2, 'Pediatría', null, 0),
  ],
);

/// [count] médicos, de mayor a menor porcentaje.
AbsenceStatistics _doctors(int count) => AbsenceStatistics(
  from: DateTime.utc(2026, 10, 1),
  to: DateTime.utc(2026, 10, 31),
  groupedBy: 'MEDICO',
  items: [
    for (var i = 0; i < count; i++)
      _percentGroup(
        i + 1,
        'Médico ${i + 1}',
        'Rodríguez Altamirano',
        99 - i * 5,
      ),
  ],
);

Future<void> _consult(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('stats-consult')));
  await tester.pumpAndSettle();
}

Finder _errorWith(String message) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key == const Key('stats-error') &&
      widget.data == message,
);

void main() {
  testWidgets('al abrir pide especialidad y muestra el cargando', (
    tester,
  ) async {
    final completer = Completer<AbsenceStatistics>();
    final repository = _Repository((_) => completer.future);
    await _pump(tester, repository);
    await tester.pump();

    expect(find.byKey(const Key('stats-loading')), findsOneWidget);
    expect(find.text('Calculando estadísticas'), findsOneWidget);
    expect(find.byKey(const Key('stats-period-label')), findsNothing);
    expect(repository.calls, [
      (from: null, to: null, grouping: AbsenceGrouping.specialty),
    ]);

    completer.complete(_bySpecialty());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-loading')), findsNothing);
  });

  testWidgets('muestra los grupos con la cantidad y el porcentaje', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    expect(_inCards('Cardiología'), findsOneWidget);
    expect(_inCards('3 inasistencias de 25'), findsOneWidget);
    expect(_inCards('12 %'), findsOneWidget);
    expect(_inCards('Pediatría'), findsOneWidget);
    expect(_inCards('0 inasistencias de 10'), findsOneWidget);
    expect(_inCards('0 %'), findsOneWidget);
    expect(find.text('Agrupar por'), findsOneWidget);
  });

  testWidgets('el período es el de la respuesta y queda encima del resultado', (
    tester,
  ) async {
    await _pump(tester, _Repository());
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('stats-period-label'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(_inCards('Cardiología')).dy),
    );
  });

  testWidgets('el período usa las fechas de la respuesta, no las tipeadas', (
    tester,
  ) async {
    final repository = _Repository(
      (call) async => _bySpecialty(
        from: DateTime.utc(2026, 9, 1),
        to: DateTime.utc(2026, 9, 30),
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
    await tester.enterText(find.byKey(const Key('stats-to')), '20/10/2026');
    await _consult(tester);

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last.from, DateTime.utc(2026, 10, 5));
    expect(repository.calls.last.to, DateTime.utc(2026, 10, 20));
    expect(repository.calls.last.grouping, AbsenceGrouping.specialty);
    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/09/2026 al 30/09/2026',
    );
  });

  testWidgets('sin filas dice Sin datos y igual muestra el período', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repository((_) async => _bySpecialty(items: const [])),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-empty')), findsOneWidget);
    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.text('Cardiología'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
  });

  testWidgets('un 403 avisa con el mensaje propio y no muestra el período', (
    tester,
  ) async {
    final repository = _Repository(
      (_) async => throw const AbsenceStatisticsException(
        AbsenceStatisticsFailure.forbidden,
        'Sin permiso',
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(
      _errorWith('Tu cuenta no tiene permiso para ver las estadísticas.'),
      findsOneWidget,
    );
    expect(find.text('Sin permiso'), findsNothing);
    expect(find.byKey(const Key('stats-period-label')), findsNothing);
  });

  testWidgets('si una consulta posterior falla no queda el período', (
    tester,
  ) async {
    var calls = 0;
    final repository = _Repository((_) async {
      if (calls++ == 0) return _bySpecialty();
      throw const AbsenceStatisticsException(
        AbsenceStatisticsFailure.forbidden,
        'Sin permiso',
      );
    });
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-period-label')), findsOneWidget);

    await _consult(tester);

    expect(find.byKey(const Key('stats-period-label')), findsNothing);
    expect(find.byKey(const Key('stats-error')), findsOneWidget);
  });

  testWidgets('mientras carga de nuevo no muestra el período', (tester) async {
    final completer = Completer<AbsenceStatistics>();
    var calls = 0;
    final repository = _Repository((_) {
      if (calls++ == 0) return Future.value(_bySpecialty());
      return completer.future;
    });
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('stats-consult')));
    await tester.pump();

    expect(find.byKey(const Key('stats-loading')), findsOneWidget);
    expect(find.byKey(const Key('stats-period-label')), findsNothing);

    completer.complete(_bySpecialty());
    await tester.pumpAndSettle();
  });

  testWidgets('cambiar a médico vuelve a pedir y muestra ese grupo', (
    tester,
  ) async {
    final repository = _Repository((call) async {
      if (call.grouping == AbsenceGrouping.doctor) return _byDoctor();
      return _bySpecialty();
    });
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Médico'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(repository.calls.last, (
      from: null,
      to: null,
      grouping: AbsenceGrouping.doctor,
    ));
    expect(_inCards('Carla Méndez'), findsOneWidget);
    expect(_inCards('4 inasistencias de 10'), findsOneWidget);
    expect(_inCards('40 %'), findsOneWidget);
    expect(find.text('Cardiología'), findsNothing);
  });

  testWidgets('el conteo va en singular solo cuando es exactamente 1', (
    tester,
  ) async {
    final repository = _Repository(
      (_) async => _bySpecialty(
        items: [
          _specialty('Cardiología', 3, 0, 10, '0 %'),
          _specialty('Pediatría', 2, 1, 1, '100 %'),
          _specialty('Oftalmología', 5, 4, 10, '40 %'),
        ],
      ),
    );
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(_inCards('0 inasistencias de 10'), findsOneWidget);
    expect(_inCards('1 inasistencia de 1'), findsOneWidget);
    expect(_inCards('4 inasistencias de 10'), findsOneWidget);
    expect(find.text('1 inasistencias de 1'), findsNothing);
  });

  testWidgets('la pantalla de estadísticas incluye la pestaña', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: StatisticsScreen())),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(6));
    expect(find.byKey(const Key('stats-tab-absences')), findsOneWidget);
    expect(find.text('Inasistencias'), findsOneWidget);
  });

  group('a 320 px con Roboto', () {
    setUpAll(loadRoboto);

    testWidgets('no hay desbordes', (tester) async {
      await _pump(tester, _Repository(), size: const Size(320, 2400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_inCards('Cardiología'), findsOneWidget);
      expect(_inCards('12 %'), findsOneWidget);
      expect(find.byKey(const Key('stats-period-label')), findsOneWidget);
      expect(find.text('Agrupar por'), findsOneWidget);
    });

    testWidgets('con el texto al doble y doce médicos no hay desbordes ni '
        'cortes', (tester) async {
      await _pump(
        tester,
        _Repository((_) async => _doctors(12)),
        size: const Size(320, 6000),
        textScale: 2,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_tracks(), 10);
      for (final text in [
        'Porcentaje de inasistencia por especialidad',
        'Los 10 mayores de 12',
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(tester.getRect(find.text(text)).right, lessThanOrEqualTo(320));
      }
    });
  });

  group('el gráfico junto a las tarjetas', () {
    testWidgets('por especialidad hay 6 filas en el gráfico y 6 tarjetas', (
      tester,
    ) async {
      await _pump(tester, _Repository((_) async => _specialties()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('absence-chart')), findsOneWidget);
      expect(
        find.text('Porcentaje de inasistencia por especialidad'),
        findsOneWidget,
      );
      expect(_tracks(), 6);
      expect(find.byType(Card), findsNWidgets(6));
      expect(find.textContaining('Los 10 mayores'), findsNothing);
    });

    testWidgets('por médico hay 10 filas en el gráfico, el aviso y 12 '
        'tarjetas', (tester) async {
      final repository = _Repository((call) async {
        if (call.grouping == AbsenceGrouping.doctor) return _doctors(12);
        return _specialties();
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Médico'));
      await tester.pumpAndSettle();

      expect(
        find.text('Porcentaje de inasistencia por médico'),
        findsOneWidget,
      );
      expect(
        find.text('Porcentaje de inasistencia por especialidad'),
        findsNothing,
      );
      expect(_tracks(), 10);
      expect(find.text('Los 10 mayores de 12'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(12));
    });

    testWidgets('al volver a especialidad el gráfico vuelve a ser el de '
        'especialidades', (tester) async {
      final repository = _Repository((call) async {
        if (call.grouping == AbsenceGrouping.doctor) return _doctors(12);
        return _specialties();
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Médico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Especialidad'));
      await tester.pumpAndSettle();

      expect(
        find.text('Porcentaje de inasistencia por especialidad'),
        findsOneWidget,
      );
      expect(_tracks(), 6);
      expect(find.textContaining('Los 10 mayores'), findsNothing);
    });

    testWidgets('el gráfico va arriba y las tarjetas debajo, con el período '
        'encima de todo', (tester) async {
      await _pump(tester, _Repository((_) async => _specialties()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('absence-chart')), findsOneWidget);
      final period = tester.getBottomLeft(
        find.byKey(const Key('stats-period-label')),
      );
      final chart = tester.getRect(find.byKey(const Key('absence-chart')));
      final firstCard = tester.getRect(find.byType(Card).first);
      expect(period.dy, lessThanOrEqualTo(chart.top));
      expect(chart.bottom, lessThanOrEqualTo(firstCard.top));
    });

    testWidgets('sin grupos no hay gráfico y dice Sin datos', (tester) async {
      await _pump(
        tester,
        _Repository((_) async => _bySpecialty(items: const [])),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('absence-chart')), findsNothing);
      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('con un error no hay gráfico', (tester) async {
      await _pump(
        tester,
        _Repository(
          (_) async => throw const AbsenceStatisticsException(
            AbsenceStatisticsFailure.forbidden,
            'Sin permiso',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-error')), findsOneWidget);
      expect(find.byKey(const Key('absence-chart')), findsNothing);
    });

    testWidgets('mientras carga de nuevo no queda el gráfico anterior', (
      tester,
    ) async {
      final completer = Completer<AbsenceStatistics>();
      var calls = 0;
      final repository = _Repository((_) {
        if (calls++ == 0) return Future.value(_specialties());
        return completer.future;
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('absence-chart')), findsOneWidget);

      await tester.tap(find.text('Médico'));
      await tester.pump();

      expect(find.byKey(const Key('stats-loading')), findsOneWidget);
      expect(find.byKey(const Key('absence-chart')), findsNothing);

      completer.complete(_doctors(3));
      await tester.pumpAndSettle();
    });
  });
}
