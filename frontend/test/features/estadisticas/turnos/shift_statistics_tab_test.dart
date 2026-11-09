import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/estadisticas/tabs/shift_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/turnos/models/shift_utilization.dart';
import 'package:agenda_medica/features/estadisticas/turnos/providers/shift_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/turnos/repositories/shift_statistics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

typedef _Call = ({DateTime? from, DateTime? to});

ShiftUtilizationItem _item({
  required int id,
  required String first,
  required String last,
  required String specialty,
  required String clinic,
  required String location,
  required int weekday,
  required int offered,
  required int occupied,
  required double? percentage,
  required String text,
}) => ShiftUtilizationItem(
  shiftId: id,
  doctor: DoctorRef(id: id, firstName: first, lastName: last),
  specialty: Specialty(id: id, name: specialty, requiresReferral: false),
  clinic: Clinic(id: id, name: clinic, location: location),
  weekday: weekday,
  activeDates: 4,
  offered: offered,
  occupied: occupied,
  percentage: percentage,
  utilization: text,
);

ShiftUtilization _result({
  List<ShiftUtilizationItem>? items,
  DateTime? from,
  DateTime? to,
}) =>
    ShiftUtilization(
      from: from ?? DateTime.utc(2026, 10, 1),
      to: to ?? DateTime.utc(2026, 10, 31),
      items:
          items ??
          [
            _item(
              id: 120,
              first: 'Marta',
              last: 'Rodríguez',
              specialty: 'Cardiología',
              clinic: 'Consultorio 5',
              location: 'Piso 2, ala norte',
              weekday: 2,
              offered: 12,
              occupied: 9,
              percentage: 75.0,
              text: '75 %',
            ),
            _item(
              id: 121,
              first: 'Jorge',
              last: 'Pereira',
              specialty: 'Medicina General',
              clinic: 'Consultorio 6',
              location: 'Piso 2, ala sur',
              weekday: 4,
              offered: 0,
              occupied: 0,
              percentage: null,
              text: 'Sin datos',
            ),
            _item(
              id: 122,
              first: 'Laura',
              last: 'Gómez',
              specialty: 'Pediatría',
              clinic: 'Consultorio 2',
              location: 'Planta baja',
              weekday: 1,
              offered: 8,
              occupied: 3,
              percentage: 37.5,
              text: '37,5 %',
            ),
            _item(
              id: 123,
              first: 'Marta',
              last: 'Rodríguez',
              specialty: 'Cardiología',
              clinic: 'Consultorio 5',
              location: 'Piso 2, ala norte',
              weekday: 5,
              offered: 10,
              occupied: 10,
              percentage: 100.0,
              text: '100 %',
            ),
          ],
    );

class _Repository implements ShiftStatisticsRepository {
  _Repository([this.responder]);

  Future<ShiftUtilization> Function(_Call call)? responder;
  final calls = <_Call>[];

  @override
  Future<ShiftUtilization> utilization({DateTime? from, DateTime? to}) {
    final call = (from: from, to: to);
    calls.add(call);
    return responder?.call(call) ?? Future.value(_result());
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(900, 2000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shiftStatisticsRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: ShiftStatisticsTab())),
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

/// La fila [index] de la tabla (pantalla ancha).
Finder _tableRow(int index) => find.byKey(Key('stats-shift-row-$index'));

/// La tarjeta [index] (pantalla angosta).
Finder _card(int index) => find.byKey(Key('stats-shift-card-$index'));

Finder _in(Finder container, String text) =>
    find.descendant(of: container, matching: find.text(text));

Finder _barIn(Finder container) => find.descendant(
  of: container,
  matching: find.byType(LinearProgressIndicator),
);

/// En cuántas líneas se dibuja el tramo `[start, end)` del texto: las cajas
/// de la selección se agrupan por su borde superior, una altura por línea.
int _lineCount(RenderParagraph paragraph, int start, int end) => {
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  ))
    box.top.round(),
}.length;

const _narrow = Size(320, 2400);

void main() {
  setUpAll(loadRoboto);

  testWidgets(
    'al abrir consulta una vez sin parámetros y muestra el cargando',
    (tester) async {
      final completer = Completer<ShiftUtilization>();
      final repository = _Repository((_) => completer.future);
      await _pump(tester, repository);
      await tester.pump();

      expect(find.byKey(const Key('stats-loading')), findsOneWidget);
      expect(find.text('Calculando estadísticas'), findsOneWidget);
      expect(repository.calls, hasLength(1));
      expect(repository.calls.single, (from: null, to: null));

      completer.complete(_result());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-loading')), findsNothing);
      expect(repository.calls, hasLength(1));
      expect(_tableRow(3), findsOneWidget);
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
  });

  testWidgets('Consultar con otro Desde cambia el texto a la respuesta', (
    tester,
  ) async {
    final repository = _Repository(
      (call) async => _result(
        from: call.from ?? DateTime.utc(2026, 10, 1),
        to: call.to ?? DateTime.utc(2026, 10, 31),
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
    final completer = Completer<ShiftUtilization>();
    final repository = _Repository((_) => completer.future);
    await _pump(tester, repository);
    await tester.pump();

    expect(find.byKey(const Key('stats-period-label')), findsNothing);

    completer.complete(_result());
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

  group('pantalla ancha (tabla)', () {
    testWidgets('a 900 px aparece la tabla y no las tarjetas', (tester) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-shift-table')), findsOneWidget);
      expect(_tableRow(0), findsOneWidget);
      expect(_card(0), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra cuatro filas en el orden del servidor', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      expect(_tableRow(4), findsNothing);
      expect(_in(_tableRow(0), 'Martes'), findsOneWidget);
      expect(_in(_tableRow(1), 'Jueves'), findsOneWidget);
      expect(_in(_tableRow(2), 'Lunes'), findsOneWidget);
      expect(_in(_tableRow(3), 'Viernes'), findsOneWidget);
      final tops = [
        for (var i = 0; i < 4; i++) tester.getTopLeft(_tableRow(i)).dy,
      ];
      expect(tops, [...tops]..sort());
    });

    testWidgets('Marta Rodríguez del martes: 9 de 12 números, 75 % y barra', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      final row = _tableRow(0);
      expect(_in(row, 'Marta Rodríguez'), findsOneWidget);
      expect(_in(row, 'Cardiología'), findsOneWidget);
      expect(_in(row, 'Consultorio 5 (Piso 2, ala norte)'), findsOneWidget);
      expect(_in(row, '9 de 12 números'), findsOneWidget);
      expect(_in(row, '75 %'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_barIn(row)).value,
        closeTo(0.75, 1e-9),
      );
    });

    testWidgets('Jorge Pereira del jueves: 0 de 0 números, Sin datos y sin '
        'barra', (tester) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      final row = _tableRow(1);
      expect(_in(row, 'Jorge Pereira'), findsOneWidget);
      expect(_in(row, '0 de 0 números'), findsOneWidget);
      expect(_in(row, 'Sin datos'), findsOneWidget);
      expect(_in(row, '0 %'), findsNothing);
      expect(_barIn(row), findsNothing);
    });

    testWidgets('Laura Gómez del lunes: 3 de 8 números, 37,5 % y barra', (
      tester,
    ) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      final row = _tableRow(2);
      expect(_in(row, 'Laura Gómez'), findsOneWidget);
      expect(_in(row, '3 de 8 números'), findsOneWidget);
      expect(_in(row, '37,5 %'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_barIn(row)).value,
        closeTo(0.375, 1e-9),
      );
    });

    testWidgets('Marta Rodríguez del viernes: 10 de 10 números, 100 % y barra '
        'llena', (tester) async {
      await _pump(tester, _Repository());
      await tester.pumpAndSettle();

      final row = _tableRow(3);
      expect(_in(row, '10 de 10 números'), findsOneWidget);
      expect(_in(row, '100 %'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_barIn(row)).value,
        closeTo(1.0, 1e-9),
      );
    });

    testWidgets('el porcentaje se muestra tal cual lo manda el servidor', (
      tester,
    ) async {
      final repository = _Repository(
        (_) async => _result(
          items: [
            _item(
              id: 1,
              first: 'Ana',
              last: 'Silva',
              specialty: 'Pediatría',
              clinic: 'Consultorio 1',
              location: 'Piso 1',
              weekday: 3,
              offered: 3,
              occupied: 1,
              percentage: 33.333333,
              text: '33 por ciento',
            ),
          ],
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_in(_tableRow(0), '33 por ciento'), findsOneWidget);
      expect(find.textContaining('33,3'), findsNothing);
    });
  });

  group('pantalla angosta (tarjetas)', () {
    testWidgets('a 320 px aparecen tarjetas, sin tabla y sin desbordes', (
      tester,
    ) async {
      await _pump(tester, _Repository(), size: _narrow);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-shift-table')), findsNothing);
      expect(_tableRow(0), findsNothing);
      expect(find.byKey(const Key('stats-period-label')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(_card(i), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('cada tarjeta muestra los mismos datos que la tabla', (
      tester,
    ) async {
      await _pump(tester, _Repository(), size: _narrow);
      await tester.pumpAndSettle();

      expect(_in(_card(0), 'Marta Rodríguez'), findsOneWidget);
      expect(_in(_card(0), 'Martes'), findsOneWidget);
      expect(_in(_card(0), '9 de 12 números'), findsOneWidget);
      expect(
        _in(_card(0), 'Consultorio 5 (Piso 2, ala norte)'),
        findsOneWidget,
      );
      expect(_in(_card(0), '75 %'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_barIn(_card(0))).value,
        closeTo(0.75, 1e-9),
      );
      expect(_in(_card(1), 'Jueves'), findsOneWidget);
      expect(_in(_card(1), '0 de 0 números'), findsOneWidget);
      expect(_in(_card(1), 'Sin datos'), findsOneWidget);
      expect(_barIn(_card(1)), findsNothing);
      expect(_in(_card(2), '37,5 %'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_barIn(_card(2))).value,
        closeTo(0.375, 1e-9),
      );
      expect(_in(_card(3), '100 %'), findsOneWidget);
      expect(
        tester.widget<LinearProgressIndicator>(_barIn(_card(3))).value,
        closeTo(1.0, 1e-9),
      );
    });

    testWidgets('ninguna palabra de las tarjetas se parte a mitad', (
      tester,
    ) async {
      await _pump(tester, _Repository(), size: _narrow);
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        final paragraphs = find.descendant(
          of: _card(i),
          matching: find.byType(RichText),
        );
        expect(
          paragraphs,
          findsWidgets,
          reason: 'la tarjeta $i no tiene texto',
        );
        for (final element in paragraphs.evaluate()) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byWidget(element.widget),
          );
          final text = paragraph.text.toPlainText();
          var offset = 0;
          for (final word in text.split(' ')) {
            expect(
              _lineCount(paragraph, offset, offset + word.length),
              1,
              reason: '"$word" en la tarjeta $i',
            );
            offset += word.length + 1;
          }
        }
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

  testWidgets('sin filas muestra el aviso de que no hay turnos', (
    tester,
  ) async {
    final repository = _Repository((_) async => _result(items: const []));
    await _pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-empty')), findsOneWidget);
    expect(find.text('No hay turnos en el período.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('stats-period-label'))).data,
      'Datos del 01/10/2026 al 31/10/2026',
    );
  });

  group('errores', () {
    testWidgets('un 400 muestra el mensaje del servidor', (tester) async {
      final repository = _Repository(
        (_) async => throw const ShiftStatisticsException(
          ShiftStatisticsFailure.validation,
          'desde debe tener formato YYYY-MM-DD',
        ),
      );
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(_errorWith('desde debe tener formato YYYY-MM-DD'), findsOneWidget);
    });

    testWidgets('un 401 pide iniciar sesión nuevamente', (tester) async {
      final repository = _Repository(
        (_) async => throw const ShiftStatisticsException(
          ShiftStatisticsFailure.unauthenticated,
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
        (_) async => throw const ShiftStatisticsException(
          ShiftStatisticsFailure.forbidden,
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
          throw const ShiftStatisticsException(
            ShiftStatisticsFailure.validation,
            'Fechas inválidas',
          );
        }
        return _result();
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
      expect(_tableRow(0), findsOneWidget);
    });

    testWidgets('Reintentar tras un fallo inicial pide sin parámetros', (
      tester,
    ) async {
      var fail = true;
      final repository = _Repository((_) async {
        if (fail) throw const ApiException();
        return _result();
      });
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      fail = false;
      await tester.tap(find.byKey(const Key('stats-retry')));
      await tester.pumpAndSettle();

      expect(repository.calls, hasLength(2));
      expect(repository.calls.last, (from: null, to: null));
      expect(_tableRow(0), findsOneWidget);
    });
  });
}
