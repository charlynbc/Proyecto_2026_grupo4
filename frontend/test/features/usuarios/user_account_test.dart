import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee puedeInactivar del listado', () {
    final socio = UserAccount.fromJson({
      'id': 42,
      'ci': '45678911',
      'nombre': 'Lucía',
      'apellido': 'Fernández',
      'rol': 'SOCIO',
      'correo': 'lucia.fernandez@example.org',
      'estado': 'ACTIVA',
      'activada': true,
      'fechaAlta': '2026-09-01T09:00:00-03:00',
      'puedeInactivar': false,
    });

    expect(socio.id, 42);
    expect(socio.ci, '45678911');
    expect(socio.firstName, 'Lucía');
    expect(socio.lastName, 'Fernández');
    expect(socio.role, UserRole.socio);
    expect(socio.email, 'lucia.fernandez@example.org');
    expect(socio.status, AccountStatus.active);
    expect(socio.activated, isTrue);
    expect(socio.createdAt, DateTime.parse('2026-09-01T09:00:00-03:00'));
    expect(socio.canDeactivate, isFalse);

    final medico = UserAccount.fromJson({
      'id': 7,
      'ci': '56789016',
      'nombre': 'Esteban',
      'apellido': 'Silva',
      'rol': 'MEDICO',
      'correo': 'esteban.silva@example.org',
      'estado': 'ACTIVA',
      'activada': true,
      'fechaAlta': '2026-09-01T09:00:00-03:00',
      'puedeInactivar': true,
    });

    expect(medico.role, UserRole.medico);
    expect(medico.status, AccountStatus.active);
    expect(medico.canDeactivate, isTrue);
  });

  test('si falta puedeInactivar se lee como verdadero', () {
    final row = UserAccount.fromJson({
      'id': 42,
      'ci': '45678911',
      'nombre': 'Lucía',
      'apellido': 'Fernández',
      'rol': 'SOCIO',
      'correo': 'lucia.fernandez@example.org',
      'estado': 'ACTIVA',
      'activada': true,
      'fechaAlta': '2026-09-01T09:00:00-03:00',
    });

    expect(row.canDeactivate, isTrue);
  });
}
