import 'package:agenda_medica/features/agendas/models/schedule_status_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scheduleStatusLabel', () {
    test('los siete estados en español', () {
      expect(scheduleStatusLabel('AGENDADA'), 'Agendada');
      expect(scheduleStatusLabel('ATENDIDA'), 'Atendida');
      expect(scheduleStatusLabel('CANCELADA_SOCIO'), 'Cancelada por el socio');
      expect(
        scheduleStatusLabel('CANCELADA_INSTITUCION'),
        'Cancelada por la institución',
      );
      expect(scheduleStatusLabel('NO_SE_PRESENTO'), 'No se presentó');
      expect(scheduleStatusLabel('NO_ASISTIO'), 'No asistió');
      expect(scheduleStatusLabel('NO_ATENDIDA'), 'No atendida');
    });

    test(
      'la lista de estados para el filtro tiene los siete, en ese orden',
      () {
        expect(kScheduleStatusLabels.keys.toList(), [
          'AGENDADA',
          'ATENDIDA',
          'CANCELADA_SOCIO',
          'CANCELADA_INSTITUCION',
          'NO_SE_PRESENTO',
          'NO_ASISTIO',
          'NO_ATENDIDA',
        ]);
      },
    );

    test('un estado que no se conoce se muestra tal cual', () {
      expect(scheduleStatusLabel('OTRO'), 'OTRO');
    });
  });
}
