/// Las columnas exactas del CSV de la carga masiva, en este orden. La usan
/// la previsualización falsa y la descarga de las filas con error.
const List<String> kUserImportColumns = [
  'ci',
  'nombre',
  'apellido',
  'fecha_nacimiento',
  'correo',
  'telefono_1',
  'telefono_2',
  'direccion',
  'rol',
  'especialidades',
];

/// Una fila de la carga masiva de usuarios (`Fila`, contrato #54 y #55).
///
/// [number] cuenta desde 2 (la 1 es el encabezado). Los datos pueden venir
/// nulos en una fila mal formada, y [error] es nulo en toda fila válida.
class UserImportRow {
  const UserImportRow({
    required this.number,
    this.ci,
    this.firstName,
    this.lastName,
    this.role,
    this.error,
  });

  factory UserImportRow.fromJson(Map<String, dynamic> json) => UserImportRow(
    number: json['numero'] as int,
    ci: json['ci'] as String?,
    firstName: json['nombre'] as String?,
    lastName: json['apellido'] as String?,
    role: json['rol'] as String?,
    error: json['error'] as String?,
  );

  final int number;
  final String? ci;
  final String? firstName;
  final String? lastName;
  final String? role;

  /// El motivo del rechazo, tal como lo manda el servidor (puede venir sin
  /// tildes). `null` si la fila es válida.
  final String? error;
}

List<UserImportRow> _rowsFromJson(Object? json) => [
  for (final item in json as List<dynamic>)
    UserImportRow.fromJson(item as Map<String, dynamic>),
];

/// La previsualización de la carga (contrato #54): qué filas sirven y
/// cuáles no, sin crear nada.
class UserImportPreview {
  const UserImportPreview({
    required this.total,
    required this.valid,
    required this.invalid,
    required this.rows,
    required this.errors,
  });

  factory UserImportPreview.fromJson(Map<String, dynamic> json) =>
      UserImportPreview(
        total: json['total'] as int,
        valid: json['validas'] as int,
        invalid: json['invalidas'] as int,
        rows: _rowsFromJson(json['filas']),
        errors: _rowsFromJson(json['errores']),
      );

  final int total;
  final int valid;
  final int invalid;

  /// Todas las filas del archivo.
  final List<UserImportRow> rows;

  /// Solo las filas con error.
  final List<UserImportRow> errors;
}

/// El resultado de confirmar la carga (contrato #55): éxito parcial, las
/// filas válidas se importan y las demás se rechazan con su motivo.
class UserImportResult {
  const UserImportResult({
    required this.total,
    required this.imported,
    required this.rejected,
    required this.rows,
    required this.errors,
  });

  /// El contrato no lista `total` en esta respuesta pero el backend lo
  /// devuelve; si faltara se calcula como importadas más rechazadas.
  factory UserImportResult.fromJson(Map<String, dynamic> json) {
    final imported = json['importadas'] as int;
    final rejected = json['rechazadas'] as int;
    return UserImportResult(
      total: (json['total'] as int?) ?? imported + rejected,
      imported: imported,
      rejected: rejected,
      rows: _rowsFromJson(json['filas']),
      errors: _rowsFromJson(json['errores']),
    );
  }

  final int total;
  final int imported;
  final int rejected;
  final List<UserImportRow> rows;
  final List<UserImportRow> errors;
}
