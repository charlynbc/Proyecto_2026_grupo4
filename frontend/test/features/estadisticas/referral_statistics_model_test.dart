import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
