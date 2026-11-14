import 'package:agenda_medica/features/estadisticas/time_slots/models/time_slot_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee día, hora y cantidad de la respuesta del servidor', () {
    final result = TimeSlotStatistics.fromJson({
      'desde': '2026-10-01',
      'hasta': '2026-10-31',
      'vista': 'LLEGADAS',
      'especialidadId': null,
      'celdas': [
        {'diaSemana': 2, 'hora': 9, 'cantidad': 2},
      ],
    });
    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.cells.single.day, 2);
    expect(result.cells.single.hour, 9);
    expect(result.cells.single.count, 2);
  });
}
