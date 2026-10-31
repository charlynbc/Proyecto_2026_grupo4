import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rutas de médico y funcionario', () {
    test('cancelar una consulta del médico', () {
      expect(
        ApiRoutes.doctorAppointmentCancel(9001),
        '/api/medico/consultas/9001/cancelar',
      );
    });

    test('cancelar el turno de una fecha del médico', () {
      expect(
        ApiRoutes.doctorShiftCancel(301),
        '/api/medico/turnos/301/cancelar',
      );
    });

    test('historia clínica previa de un paciente', () {
      expect(
        ApiRoutes.doctorPatientMedicalHistory(21),
        '/api/medico/pacientes/21/historia-clinica',
      );
    });

    test('lista de atenciones del médico', () {
      expect(ApiRoutes.doctorAttentions, '/api/medico/atenciones');
    });

    test('detalle de una atención del médico', () {
      expect(ApiRoutes.doctorAttention(5530), '/api/medico/atenciones/5530');
    });

    test('pases emitidos por el médico', () {
      expect(ApiRoutes.doctorReferrals, '/api/medico/pases');
    });

    test('cancelar una consulta a pedido del socio', () {
      expect(
        ApiRoutes.staffAppointmentCancel(9001),
        '/api/funcionario/consultas/9001/cancelar',
      );
    });
  });

  group('ApiRoutes.all', () {
    for (final route in [
      '/api/medico/consultas/1/cancelar',
      '/api/medico/turnos/1/cancelar',
      '/api/medico/pacientes/1/historia-clinica',
      '/api/medico/atenciones',
      '/api/medico/atenciones/1',
      '/api/medico/pases',
      '/api/funcionario/consultas/1/cancelar',
    ]) {
      test('incluye $route', () {
        expect(ApiRoutes.all, contains(route));
      });
    }
  });
}
