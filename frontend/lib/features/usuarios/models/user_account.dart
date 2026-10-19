import '../../auth/models/user_role.dart';

/// `EstadoCuenta`: habilitada o inactivada por un administrador. No es lo
/// mismo que "activada": una cuenta `ACTIVA` puede no haber completado todavía
/// el primer ingreso.
enum AccountStatus {
  active('ACTIVA', 'Activo'),
  inactive('INACTIVA', 'Inactivo');

  const AccountStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static AccountStatus fromApi(String value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Estado de cuenta desconocido: $value');
  }
}

/// Una fila del padrón (`UsuarioDTO`, contrato #12): una por cuenta.
class UserAccount {
  const UserAccount({
    required this.id,
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.email,
    required this.status,
    required this.activated,
    required this.createdAt,
  });

  final int id;
  final String ci;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String email;
  final AccountStatus status;

  /// La persona ya completó el primer ingreso.
  final bool activated;

  /// Fecha de alta (`fechaAlta`), un instante.
  final DateTime createdAt;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final role = UserRole.tryParse(json['rol'] as String?);
    if (role == null) {
      throw FormatException('Rol desconocido: ${json['rol']}');
    }
    return UserAccount(
      id: json['id'] as int,
      ci: json['ci'] as String,
      firstName: json['nombre'] as String,
      lastName: json['apellido'] as String,
      role: role,
      email: json['correo'] as String,
      status: AccountStatus.fromApi(json['estado'] as String),
      activated: json['activada'] as bool,
      createdAt: DateTime.parse(json['fechaAlta'] as String),
    );
  }
}
