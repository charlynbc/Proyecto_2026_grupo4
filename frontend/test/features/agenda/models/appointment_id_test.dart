import 'package:agenda_medica/features/agenda/models/appointment_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completa con ceros a la izquierda hasta 6 dígitos', () {
    expect(formatAppointmentId(9001), '009001');
    expect(formatAppointmentId(123), '000123');
    expect(formatAppointmentId(1), '000001');
  });

  test('un ID de 6 dígitos queda como está', () {
    expect(formatAppointmentId(123456), '123456');
  });

  test('un ID de más de 6 dígitos queda como está', () {
    expect(formatAppointmentId(1234567), '1234567');
  });
}
