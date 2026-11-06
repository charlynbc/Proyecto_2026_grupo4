import '../../auth/models/user_role.dart';

/// Los datos de la cuenta de quien está logueado (`GET /api/cuentas/me`,
/// contrato, fila 46). RF-06 lectura.
///
/// CI, nombre, apellido y rol se muestran pero no se editan por esta vía:
/// los corrige el Administrador (RF-38).
class Account {
  const Account({
    required this.ci,
    required this.name,
    required this.lastName,
    required this.role,
    required this.email,
    required this.pendingEmail,
    required this.phone1,
    required this.phone2,
    required this.address,
  });

  /// Un rol que no es de los cuatro del contrato es [FormatException]; un
  /// dato obligatorio que falta es un `TypeError` del cast.
  factory Account.fromJson(Map<String, dynamic> json) => Account(
    ci: json['ci'] as String,
    name: json['nombre'] as String,
    lastName: json['apellido'] as String,
    role: _roleFromApi(json['rol'] as String),
    email: json['correo'] as String,
    pendingEmail: json['correoPendiente'] as String?,
    phone1: json['telefono1'] as String,
    phone2: json['telefono2'] as String?,
    address: json['direccion'] as String,
  );

  final String ci;
  final String name;
  final String lastName;
  final UserRole role;
  final String email;

  /// El correo nuevo a la espera de confirmación, o `null` si no hay un
  /// cambio pendiente.
  final String? pendingEmail;

  final String phone1;
  final String? phone2;
  final String address;
}

UserRole _roleFromApi(String value) =>
    UserRole.tryParse(value) ??
    (throw FormatException('Rol de cuenta desconocido', value));
