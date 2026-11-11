import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/account_status_change.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lee la respuesta de una cuenta inactivada', () {
    final change = AccountStatusChange.fromJson({
      'id': 42,
      'ci': '45678911',
      'nombre': 'Lucía',
      'apellido': 'Fernández',
      'rol': 'MEDICO',
      'estado': 'INACTIVA',
      'ultimaInactivacionEn': '2026-11-04T12:00:00-03:00',
      'ultimaInactivacionPor': 1,
      'ultimaReactivacionEn': null,
      'ultimaReactivacionPor': null,
    });

    expect(change.id, 42);
    expect(change.ci, '45678911');
    expect(change.firstName, 'Lucía');
    expect(change.lastName, 'Fernández');
    expect(change.role, UserRole.medico);
    expect(change.status, AccountStatus.inactive);
    expect(change.lastDeactivatedAt, DateTime.utc(2026, 11, 4, 15));
    expect(change.lastDeactivatedBy, 1);
    expect(change.lastReactivatedAt, isNull);
    expect(change.lastReactivatedBy, isNull);
  });

  test('lee la respuesta de una cuenta reactivada', () {
    final change = AccountStatusChange.fromJson({
      'id': 42,
      'ci': '45678911',
      'nombre': 'Lucía',
      'apellido': 'Fernández',
      'rol': 'FUNCIONARIO',
      'estado': 'ACTIVA',
      'ultimaInactivacionEn': '2026-11-04T12:00:00-03:00',
      'ultimaInactivacionPor': 1,
      'ultimaReactivacionEn': '2026-11-05T09:30:00-03:00',
      'ultimaReactivacionPor': 7,
    });

    expect(change.role, UserRole.funcionario);
    expect(change.status, AccountStatus.active);
    expect(change.lastDeactivatedAt, DateTime.utc(2026, 11, 4, 15));
    expect(change.lastDeactivatedBy, 1);
    expect(change.lastReactivatedAt, DateTime.utc(2026, 11, 5, 12, 30));
    expect(change.lastReactivatedBy, 7);
  });

  test('un rol o un estado desconocidos son un error de formato', () {
    Map<String, dynamic> json({
      String rol = 'MEDICO',
      String estado = 'ACTIVA',
    }) => {
      'id': 1,
      'ci': '1',
      'nombre': 'A',
      'apellido': 'B',
      'rol': rol,
      'estado': estado,
      'ultimaInactivacionEn': null,
      'ultimaInactivacionPor': null,
      'ultimaReactivacionEn': null,
      'ultimaReactivacionPor': null,
    };

    expect(
      () => AccountStatusChange.fromJson(json(rol: 'JEFE')),
      throwsFormatException,
    );
    expect(
      () => AccountStatusChange.fromJson(json(estado: 'SUSPENDIDA')),
      throwsFormatException,
    );
  });
}
