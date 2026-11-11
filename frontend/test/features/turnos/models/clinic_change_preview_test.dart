import 'package:agenda_medica/features/turnos/models/clinic_change_preview.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpreta fechas, consultas, consultorio y números en conflicto', () {
    final preview = ClinicChangePreview.fromJson({
      'fechas': [
        {
          'turnoId': 301,
          'fecha': '2026-11-11',
          'estado': 'ACTIVO',
          'consultasAgendadas': 2,
          'consultorioActual': {'id': 5, 'nombre': 'Consultorio 5'},
          'solapamientos': [
            {'numeroPropio': 1, 'numeroExistente': 3},
          ],
        },
        {
          'turnoId': 302,
          'fecha': '2026-11-18',
          'estado': 'SUSPENDIDO',
          'consultasAgendadas': 0,
          'solapamientos': [],
        },
      ],
    });

    expect(preview.dates, hasLength(2));
    final first = preview.dates.first;
    expect(first.shiftId, 301);
    expect(first.date, DateTime.utc(2026, 11, 11));
    expect(first.state, ShiftState.active);
    expect(first.bookedAppointments, 2);
    expect(first.requiresConfirmation, isTrue);
    expect(first.hasOverlaps, isTrue);
    expect(first.overlaps.single.ownNumber, 1);
    expect(first.overlaps.single.existingNumber, 3);
    expect(first.currentClinicId, 5);
    expect(first.currentClinicName, 'Consultorio 5');

    final suspended = preview.dates.last;
    expect(suspended.state, ShiftState.suspended);
    expect(suspended.requiresConfirmation, isFalse);
    expect(suspended.hasOverlaps, isFalse);
  });

  test('permite omitir los solapamientos y el consultorio actual', () {
    final preview = ClinicChangePreview.fromJson({
      'fechas': [
        {
          'turnoId': 101,
          'fecha': '2026-11-25',
          'estado': 'ACTIVO',
          'consultasAgendadas': 0,
        },
      ],
    });

    expect(preview.dates.single.overlaps, isEmpty);
    expect(preview.dates.single.currentClinicId, isNull);
  });

  test('rechaza un estado inválido y cantidades negativas', () {
    expect(
      () => ClinicChangePreviewDate.fromJson({
        'turnoId': 1,
        'fecha': '2026-11-11',
        'estado': 'DESCONOCIDO',
        'consultasAgendadas': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => ClinicChangePreviewDate.fromJson({
        'turnoId': 1,
        'fecha': '2026-11-11',
        'estado': 'ACTIVO',
        'consultasAgendadas': -1,
      }),
      throwsFormatException,
    );
  });
}
