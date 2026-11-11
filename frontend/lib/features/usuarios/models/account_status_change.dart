import '../../auth/models/user_role.dart';
import 'user_account.dart';

/// La respuesta de inactivar o reactivar una cuenta (`EstadoCuentaResponse`,
/// contrato, filas 61 y 62). No es una fila del padrón: no trae correo,
/// fecha de alta ni si la cuenta fue activada.
class AccountStatusChange {
  const AccountStatusChange({
    required this.id,
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
    this.lastDeactivatedAt,
    this.lastDeactivatedBy,
    this.lastReactivatedAt,
    this.lastReactivatedBy,
  });

  factory AccountStatusChange.fromJson(Map<String, dynamic> json) {
    final role = UserRole.tryParse(json['rol'] as String?);
    if (role == null) {
      throw FormatException('Rol desconocido: ${json['rol']}');
    }
    DateTime? instant(Object? value) =>
        value == null ? null : DateTime.parse(value as String).toUtc();
    return AccountStatusChange(
      id: json['id'] as int,
      ci: json['ci'] as String,
      firstName: json['nombre'] as String,
      lastName: json['apellido'] as String,
      role: role,
      status: AccountStatus.fromApi(json['estado'] as String),
      lastDeactivatedAt: instant(json['ultimaInactivacionEn']),
      lastDeactivatedBy: json['ultimaInactivacionPor'] as int?,
      lastReactivatedAt: instant(json['ultimaReactivacionEn']),
      lastReactivatedBy: json['ultimaReactivacionPor'] as int?,
    );
  }

  final int id;
  final String ci;
  final String firstName;
  final String lastName;
  final UserRole role;
  final AccountStatus status;

  /// Instantes (UTC) y ids de administrador de la última inactivación y de la
  /// última reactivación. Son `null` si nunca ocurrieron.
  final DateTime? lastDeactivatedAt;
  final int? lastDeactivatedBy;
  final DateTime? lastReactivatedAt;
  final int? lastReactivatedBy;
}
