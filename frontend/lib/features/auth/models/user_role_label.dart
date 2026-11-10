import 'user_role.dart';

/// El texto con que se muestra un rol. Lo comparten Mi cuenta e Inicio.
String userRoleLabel(UserRole role) => switch (role) {
  UserRole.socio => 'Socio',
  UserRole.funcionario => 'Funcionario',
  UserRole.medico => 'Médico',
  UserRole.administrador => 'Administrador',
};
