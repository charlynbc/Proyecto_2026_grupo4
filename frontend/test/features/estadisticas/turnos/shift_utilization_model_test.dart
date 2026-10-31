import 'package:agenda_medica/features/estadisticas/turnos/models/shift_utilization.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shift_statistics_fixtures.dart';

/// Lo que tira `fromJson` ante una respuesta mal formada; el repositorio lo
/// convierte en el error genérico.
final _malformed = anyOf(isA<FormatException>(), isA<TypeError>());

void main() {
  test('lee las dos filas del contrato', () {
    final result = ShiftUtilization.fromJson(contractBody());

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.items, hasLength(2));

    final first = result.items[0];
    expect(first.shiftId, 120);
    expect(first.doctor.fullName, 'Marta Rodríguez');
    expect(first.specialty.name, 'Cardiología');
    expect(first.clinic.name, 'Consultorio 5');
    expect(first.clinic.location, 'Piso 2, ala norte');
    expect(first.weekday, 2);
    expect(first.activeDates, 4);
    expect(first.offered, 12);
    expect(first.occupied, 9);
    expect(first.percentage, 75.0);
    expect(first.utilization, '75 %');

    final second = result.items[1];
    expect(second.shiftId, 121);
    expect(second.percentage, isNull);
    expect(second.utilization, 'Sin datos');
  });

  test('un porcentaje entero se lee como decimal', () {
    final body = contractBody();
    firstItem(body)['porcentajeUtilizacion'] = 100;

    final item = ShiftUtilization.fromJson(body).items.first;

    expect(item.percentage, 100.0);
  });

  test('un porcentaje decimal se lee tal cual', () {
    final body = contractBody();
    firstItem(body)['porcentajeUtilizacion'] = 37.5;

    expect(ShiftUtilization.fromJson(body).items.first.percentage, 37.5);
  });

  test('el texto de utilizacion se conserva sin tocarlo', () {
    final body = contractBody();
    firstItem(body)['utilizacion'] = '37,5 %';

    expect(ShiftUtilization.fromJson(body).items.first.utilization, '37,5 %');
  });

  for (final weekday in [1, 7]) {
    test('el día $weekday es válido', () {
      final body = contractBody();
      firstItem(body)['diaSemana'] = weekday;

      expect(ShiftUtilization.fromJson(body).items.first.weekday, weekday);
    });
  }

  for (final weekday in [0, 8]) {
    test('el día $weekday es un error de formato', () {
      final body = contractBody();
      firstItem(body)['diaSemana'] = weekday;

      expect(() => ShiftUtilization.fromJson(body), throwsA(_malformed));
    });
  }

  test('numerosOcupados como texto falla', () {
    final body = contractBody();
    firstItem(body)['numerosOcupados'] = '9';

    expect(() => ShiftUtilization.fromJson(body), throwsA(_malformed));
  });

  test('un ítem sin medico falla', () {
    final body = contractBody();
    firstItem(body).remove('medico');

    expect(() => ShiftUtilization.fromJson(body), throwsA(_malformed));
  });

  test('una respuesta sin items falla', () {
    final body = contractBody()..remove('items');

    expect(() => ShiftUtilization.fromJson(body), throwsA(_malformed));
  });

  test('una fecha mal formada falla', () {
    final body = contractBody()..['desde'] = '01/10/2026';

    expect(() => ShiftUtilization.fromJson(body), throwsA(_malformed));
  });

  test('sin filas la lista queda vacía', () {
    final body = contractBody()..['items'] = <Object>[];

    expect(ShiftUtilization.fromJson(body).items, isEmpty);
  });
}
