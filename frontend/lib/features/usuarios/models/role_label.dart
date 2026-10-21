import '../../auth/models/user_role.dart';

/// Nombre del rol para mostrar al administrador.
String roleLabel(UserRole role) => switch (role) {
  UserRole.socio => 'Socio',
  UserRole.funcionario => 'Funcionario',
  UserRole.medico => 'Médico',
  UserRole.administrador => 'Administrador',
};
