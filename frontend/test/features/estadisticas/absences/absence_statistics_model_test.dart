import 'package:agenda_medica/features/estadisticas/absences/models/absence_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

/// La respuesta de la fila 69, escrita a mano.
Map<String, dynamic> _specialtyBody() => {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'agruparPor': 'ESPECIALIDAD',
  'items': <Map<String, dynamic>>[
    {
      'id': 3,
      'nombre': 'Cardiología',
      'apellido': null,
      'atendidas': 20,
      'noAsistio': 2,
      'noSePresento': 1,
      'noAtendidas': 2,
      'total': 25,
      'porcentajeInasistencia': 12.0,
      'inasistencia': '12 %',
    },
  ],
};

void main() {
  test('lee la respuesta agrupada por especialidad', () {
    final result = AbsenceStatistics.fromJson(_specialtyBody());
    final item = result.items.single;

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'ESPECIALIDAD');
    expect(item.id, 3);
    expect(item.name, 'Cardiología');
    expect(item.lastName, isNull);
    expect(item.attended, 20);
    expect(item.noShow, 2);
    expect(item.missed, 1);
    expect(item.notAttended, 2);
    expect(item.total, 25);
    expect(item.percentage, 12.0);
    expect(item.percentageText, '12 %');
  });

  test('un porcentaje entero se lee como decimal', () {
    final body = _specialtyBody();
    (body['items'] as List<Map<String, dynamic>>)[0]['porcentajeInasistencia'] =
        12;

    expect(AbsenceStatistics.fromJson(body).items.single.percentage, 12.0);
  });

  test('agrupada por médico lee el apellido', () {
    final body = _specialtyBody()..['agruparPor'] = 'MEDICO';
    final row = (body['items'] as List<Map<String, dynamic>>).single;
    row['id'] = 4;
    row['nombre'] = 'Carla';
    row['apellido'] = 'Méndez';

    final result = AbsenceStatistics.fromJson(body);
    final item = result.items.single;

    expect(result.groupedBy, 'MEDICO');
    expect(item.id, 4);
    expect(item.name, 'Carla');
    expect(item.lastName, 'Méndez');
  });

  test('sin filas la lista queda vacía y el período se conserva', () {
    final body = _specialtyBody()..['items'] = <Object>[];
    final result = AbsenceStatistics.fromJson(body);

    expect(result.items, isEmpty);
    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'ESPECIALIDAD');
  });

  test('un porcentaje 0 se lee como 0.0', () {
    final body = _specialtyBody();
    final row = (body['items'] as List<Map<String, dynamic>>).single;
    row['atendidas'] = 5;
    row['noAsistio'] = 0;
    row['noSePresento'] = 0;
    row['noAtendidas'] = 0;
    row['total'] = 5;
    row['porcentajeInasistencia'] = 0;
    row['inasistencia'] = '0 %';

    final item = AbsenceStatistics.fromJson(body).items.single;

    expect(item.attended, 5);
    expect(item.noShow, 0);
    expect(item.missed, 0);
    expect(item.notAttended, 0);
    expect(item.total, 5);
    expect(item.percentage, 0.0);
    expect(item.percentageText, '0 %');
  });
}
