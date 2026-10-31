import 'package:agenda_medica/features/estadisticas/especialidades/models/specialty_demand.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _contractBody() => {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'items': <Map<String, dynamic>>[
    {
      'especialidad': {
        'id': 1,
        'nombre': 'Medicina General',
        'requierePase': false,
      },
      'cantidadConsultas': 128,
    },
    {
      'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
      'cantidadConsultas': 42,
    },
  ],
};

/// Lo que tira `fromJson` ante una respuesta mal formada; el repositorio lo
/// convierte en el error genérico.
final _malformed = anyOf(isA<FormatException>(), isA<TypeError>());

void main() {
  test('lee la respuesta del contrato', () {
    final demand = SpecialtyDemand.fromJson(_contractBody());

    expect(demand.from, DateTime.utc(2026, 10, 1));
    expect(demand.to, DateTime.utc(2026, 10, 31));
    expect(demand.items, hasLength(2));
    expect(demand.items[0].specialty.id, 1);
    expect(demand.items[0].specialty.name, 'Medicina General');
    expect(demand.items[0].specialty.requiresReferral, isFalse);
    expect(demand.items[0].count, 128);
    expect(demand.items[1].specialty.name, 'Cardiología');
    expect(demand.items[1].specialty.requiresReferral, isTrue);
    expect(demand.items[1].count, 42);
  });

  test('el total suma las cantidades de todas las filas', () {
    expect(SpecialtyDemand.fromJson(_contractBody()).total, 170);
  });

  test('sin filas el total es 0', () {
    final body = _contractBody()..['items'] = <Object>[];
    final demand = SpecialtyDemand.fromJson(body);
    expect(demand.items, isEmpty);
    expect(demand.total, 0);
  });

  test('una respuesta sin items falla', () {
    final body = _contractBody()..remove('items');
    expect(() => SpecialtyDemand.fromJson(body), throwsA(_malformed));
  });

  test('una cantidad como texto falla', () {
    final body = _contractBody();
    (body['items'] as List<Map<String, dynamic>>)[0]['cantidadConsultas'] =
        '128';
    expect(() => SpecialtyDemand.fromJson(body), throwsA(_malformed));
  });

  test('una fecha mal formada falla', () {
    final body = _contractBody()..['desde'] = '01/10/2026';
    expect(() => SpecialtyDemand.fromJson(body), throwsA(_malformed));
  });
}
