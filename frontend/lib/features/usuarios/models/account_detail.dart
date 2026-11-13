import '../../agenda/models/agenda_time.dart';
import '../../auth/models/user_role.dart';
import 'user_account.dart';

/// El detalle completo de una cuenta (`GET /api/usuarios/{id}`, contrato,
/// fila 68, y respuesta del `PATCH` de la fila 58): lo que la pantalla de
/// corrección precarga. El listado ([UserAccount]) no trae teléfonos ni
/// dirección.
class AccountDetail {
  const AccountDetail({
    required this.id,
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.role,
    required this.email,
    required this.phone1,
    required this.phone2,
    required this.address,
    required this.specialtyIds,
    required this.status,
    required this.activated,
  });

  final int id;
  final String ci;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final UserRole role;
  final String email;
  final String phone1;
  final String? phone2;
  final String? address;
  final List<int> specialtyIds;
  final AccountStatus status;
  final bool activated;

  /// Un rol o un estado desconocidos son [FormatException]; un dato con otro
  /// tipo es un `TypeError` del cast.
  factory AccountDetail.fromJson(Map<String, dynamic> json) {
    final role = UserRole.tryParse(json['rol'] as String?);
    if (role == null) {
      throw FormatException('Rol desconocido: ${json['rol']}');
    }
    return AccountDetail(
      id: json['id'] as int,
      ci: json['ci'] as String,
      firstName: json['nombre'] as String,
      lastName: json['apellido'] as String,
      birthDate: parseApiDate(json['fechaNacimiento'] as String),
      role: role,
      email: json['correo'] as String,
      phone1: json['telefono1'] as String,
      phone2: json['telefono2'] as String?,
      address: json['direccion'] as String?,
      specialtyIds: [
        for (final id in json['especialidadIds'] as List<dynamic>) id as int,
      ],
      status: AccountStatus.fromApi(json['estado'] as String),
      activated: json['activada'] as bool,
    );
  }
}
