import 'user_role.dart';

/// Acceso por el que se entra (`TipoAcceso` del contrato). El de empleados
/// existe solo en la web (RNF-02).
enum AccessType {
  socio('SOCIO', 'socio'),
  empleado('EMPLEADO', 'empleado');

  const AccessType(this.apiValue, this.queryValue);

  /// Valor del JSON del contrato.
  final String apiValue;

  /// Valor del parámetro `?acceso=` de las rutas del cliente.
  final String queryValue;

  /// Cualquier valor que no sea `empleado` es el acceso de socios.
  static AccessType fromQuery(String? value) =>
      value == empleado.queryValue ? empleado : socio;

  /// El acceso que corresponde a una cuenta con [role].
  static AccessType forRole(UserRole role) =>
      role == UserRole.socio ? socio : empleado;
}
