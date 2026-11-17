import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(Map<String, Object?> destination) => {
  'especialidadDestino': {
    'id': 3,
    'nombre': 'Medicina General',
    ...destination,
  },
  'emitidos': 0,
  'utilizados': 0,
  'disponibles': 0,
  'vencidos': 0,
  'porcentajeUtilizados': null,
  'utilizacion': 'Sin datos',
};

void main() {
  group('requierePase de la especialidad de destino', () {
    test('se lee cuando es true o false', () {
      expect(
        ReferralItem.fromJson(_row({'requierePase': true})).requiresReferral,
        isTrue,
      );
      expect(
        ReferralItem.fromJson(_row({'requierePase': false})).requiresReferral,
        isFalse,
      );
    });

    test('ausente se trata como que sí exige pase', () {
      expect(ReferralItem.fromJson(_row({})).requiresReferral, isTrue);
    });

    test('nulo o no booleano se trata como que sí exige pase', () {
      expect(
        ReferralItem.fromJson(_row({'requierePase': null})).requiresReferral,
        isTrue,
      );
      expect(
        ReferralItem.fromJson(_row({'requierePase': 'false'})).requiresReferral,
        isTrue,
      );
      expect(
        ReferralItem.fromJson(_row({'requierePase': 0})).requiresReferral,
        isTrue,
      );
    });

    test('un campo ausente no cambia la lectura de los demás', () {
      final item = ReferralItem.fromJson({
        'especialidadDestino': {'id': 3, 'nombre': 'Cardiología'},
        'emitidos': 10,
        'utilizados': 5,
        'disponibles': 3,
        'vencidos': 2,
        'porcentajeUtilizados': 71.43,
        'utilizacion': '71.43 %',
      });
      expect(item.name, 'Cardiología');
      expect(item.issued, 10);
      expect(item.used, 5);
      expect(item.available, 3);
      expect(item.expired, 2);
      expect(item.percentage, 71.43);
      expect(item.utilization, '71.43 %');
      expect(item.requiresReferral, isTrue);
    });
  });

  test('lee los conteos y la utilización sin pases resueltos', () {
    final result = ReferralStatistics.fromJson({
      'desde': '2026-10-01',
      'hasta': '2026-10-31',
      'especialidadOrigenId': null,
      'items': [
        {
          'especialidadDestino': {
            'id': 3,
            'nombre': 'Cardiología',
            'requierePase': true,
          },
          'emitidos': 3,
          'utilizados': 0,
          'disponibles': 3,
          'vencidos': 0,
          'porcentajeUtilizados': null,
          'utilizacion': 'Sin datos',
        },
      ],
    });
    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.items.single.name, 'Cardiología');
    expect(result.items.single.utilization, 'Sin datos');
    expect(result.items.single.percentage, isNull);
  });
}
