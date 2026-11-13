import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/account_detail.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:flutter_test/flutter_test.dart';

/// La respuesta de ejemplo de la fila 68 del contrato.
Map<String, dynamic> _row68() => {
  'id': 12,
  'ci': '34567894',
  'nombre': 'Sofia Elena',
  'apellido': 'Socia',
  'fechaNacimiento': '1985-06-06',
  'rol': 'MEDICO',
  'correo': 'sofia@ejemplo.invalid',
  'telefono1': '099111222',
  'telefono2': null,
  'direccion': 'Calle Falsa 123',
  'especialidadIds': [3, 7],
  'estado': 'ACTIVA',
  'activada': true,
};

void main() {
  test('lee la respuesta de ejemplo de la fila 68', () {
    final detail = AccountDetail.fromJson(_row68());

    expect(detail.id, 12);
    expect(detail.ci, '34567894');
    expect(detail.firstName, 'Sofia Elena');
    expect(detail.lastName, 'Socia');
    expect(detail.birthDate, DateTime.utc(1985, 6, 6));
    expect(detail.role, UserRole.medico);
    expect(detail.email, 'sofia@ejemplo.invalid');
    expect(detail.phone1, '099111222');
    expect(detail.phone2, isNull);
    expect(detail.address, 'Calle Falsa 123');
    expect(detail.specialtyIds, [3, 7]);
    expect(detail.status, AccountStatus.active);
    expect(detail.activated, isTrue);
  });

  test('una cuenta inactiva de socio, con teléfono 2 y sin especialidades', () {
    final detail = AccountDetail.fromJson({
      ..._row68(),
      'id': 5,
      'rol': 'SOCIO',
      'telefono2': '098222333',
      'direccion': null,
      'especialidadIds': <int>[],
      'estado': 'INACTIVA',
      'activada': false,
    });

    expect(detail.role, UserRole.socio);
    expect(detail.phone2, '098222333');
    expect(detail.address, isNull);
    expect(detail.specialtyIds, isEmpty);
    expect(detail.status, AccountStatus.inactive);
    expect(detail.activated, isFalse);
  });

  test('un tipo incorrecto es un error de tipo', () {
    expect(
      () => AccountDetail.fromJson({..._row68(), 'id': '12'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => AccountDetail.fromJson({
        ..._row68(),
        'especialidadIds': [3, 'x'],
      }),
      throwsA(isA<TypeError>()),
    );
  });

  test('un rol o un estado desconocidos son un error de formato', () {
    expect(
      () => AccountDetail.fromJson({..._row68(), 'rol': 'JEFE'}),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AccountDetail.fromJson({..._row68(), 'estado': 'PAUSADA'}),
      throwsA(isA<FormatException>()),
    );
  });
}
