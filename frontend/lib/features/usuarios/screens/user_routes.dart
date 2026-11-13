const String kUsersPath = '/admin/usuarios';
const String kNewUserPath = '/admin/usuarios/nuevo';
const String kImportUsersPath = '/admin/usuarios/importar';

/// La corrección de los datos de la cuenta [id] (RF-38).
String userEditPath(int id) => '$kUsersPath/$id/corregir';
