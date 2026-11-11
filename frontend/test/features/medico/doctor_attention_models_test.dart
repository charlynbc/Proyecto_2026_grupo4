import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';

void main() {
  test('normaliza CI y conserva apellidos', () {
    expect(normalizePatientSearch('4.567.891-1'), '45678911');
    expect(normalizePatientSearch(' 12 345 '), '12345');
    expect(normalizePatientSearch('  De los Santos '), 'De los Santos');
    expect(normalizePatientSearch('   '), '');
  });
  test('serializa filtros explícitos', () {
    final q = DoctorAttentionQuery(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 31),
      patientText: '4.567.891-1',
      specialtyId: 3,
      order: DoctorAttentionOrder.patientLastName,
      direction: DoctorAttentionDirection.ascending,
    );
    expect(q.toQueryParameters(), {
      'fechaDesde': '2026-10-01',
      'fechaHasta': '2026-10-31',
      'paciente': '45678911',
      'especialidadId': 3,
      'orden': 'apellido',
      'sentido': 'asc',
    });
  });
  test('omite paciente en blanco y especialidad vacía', () {
    final q = DoctorAttentionQuery(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 31),
      patientText: '   ',
    );
    expect(q.toQueryParameters(), {
      'fechaDesde': '2026-10-01',
      'fechaHasta': '2026-10-31',
      'orden': 'fecha',
      'sentido': 'desc',
    });
  });
}
