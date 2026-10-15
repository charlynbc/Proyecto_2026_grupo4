/// Rol de la cuenta, tal como lo informa el servidor en la sesión (`role`).
///
/// Sirve para decidir qué secciones se muestran y a qué rutas se puede
/// entrar. Es una comodidad del cliente: la autorización real es del
/// servidor.
enum UserRole {
  socio('SOCIO', 'socio'),
  funcionario('FUNCIONARIO', 'funcionario'),
  medico('MEDICO', 'medico'),
  administrador('ADMINISTRADOR', 'admin');

  const UserRole(this.apiValue, this.routeSegment);

  /// Valor del JSON del contrato.
  final String apiValue;

  /// Primer tramo de las rutas del rol (`/socio/...`).
  final String routeSegment;

  String get routePrefix => '/$routeSegment';

  /// `null` si [value] no es un rol conocido.
  static UserRole? tryParse(String? value) {
    for (final role in values) {
      if (role.apiValue == value) return role;
    }
    return null;
  }

  /// El rol al que pertenece la ruta [path], o `null` si no es de ningún rol.
  static UserRole? fromPath(String path) {
    for (final role in values) {
      if (path == role.routePrefix || path.startsWith('${role.routePrefix}/')) {
        return role;
      }
    }
    return null;
  }
}
