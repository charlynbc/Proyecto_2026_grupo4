import '../../auth/models/user_role.dart';

/// Datos del alta de un usuario (`AltaUsuarioDTO`, contrato #11).
class NewUser {
  const NewUser({
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.email,
    required this.phone1,
    this.phone2,
    this.address,
    required this.role,
    this.specialtyIds = const [],
  });

  /// Solo dígitos, con el dígito verificador incluido.
  final String ci;
  final String firstName;
  final String lastName;

  /// Fecha de calendario: solo importan año, mes y día.
  final DateTime birthDate;
  final String email;
  final String phone1;
  final String? phone2;
  final String? address;
  final UserRole role;

  /// Una o más, solo con rol Médico; para los demás roles va vacía.
  final List<int> specialtyIds;

  Map<String, Object?> toJson() => {
    'ci': ci,
    'nombre': firstName,
    'apellido': lastName,
    'fechaNacimiento': formatApiDate(birthDate),
    'correo': email,
    'telefono1': phone1,
    'telefono2': phone2,
    'direccion': address,
    'rol': role.apiValue,
    if (role == UserRole.medico) 'especialidadIds': specialtyIds,
  };
}

/// Fecha de calendario del JSON: `yyyy-MM-dd`.
String formatApiDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
