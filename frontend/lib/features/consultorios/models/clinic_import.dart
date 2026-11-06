/// Una fila de la carga masiva de consultorios (`Fila`, contrato #56 y #57).
///
/// [number] cuenta desde 2 (la 1 es el encabezado). El nombre y la ubicación
/// pueden venir nulos en una fila mal formada, y [error] es nulo en toda fila
/// válida.
class ClinicImportRow {
  const ClinicImportRow({
    required this.number,
    this.name,
    this.location,
    this.error,
  });

  factory ClinicImportRow.fromJson(Map<String, dynamic> json) =>
      ClinicImportRow(
        number: json['numero'] as int,
        name: json['nombre'] as String?,
        location: json['ubicacion'] as String?,
        error: json['error'] as String?,
      );

  final int number;
  final String? name;
  final String? location;

  /// El motivo del rechazo, tal como lo manda el servidor. `null` si la fila
  /// es válida.
  final String? error;
}

List<ClinicImportRow> _rowsFromJson(Object? json) => [
  for (final item in json as List<dynamic>)
    ClinicImportRow.fromJson(item as Map<String, dynamic>),
];

/// La previsualización de la carga (contrato #56): qué filas sirven y cuáles
/// no, sin crear nada.
class ClinicImportPreview {
  const ClinicImportPreview({
    required this.total,
    required this.valid,
    required this.invalid,
    required this.rows,
    required this.errors,
  });

  factory ClinicImportPreview.fromJson(Map<String, dynamic> json) =>
      ClinicImportPreview(
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
  final List<ClinicImportRow> rows;

  /// Solo las filas con error.
  final List<ClinicImportRow> errors;
}

/// El resultado de confirmar la carga (contrato #57): éxito parcial, las
/// filas válidas se importan y las demás se rechazan con su motivo.
class ClinicImportResult {
  const ClinicImportResult({
    required this.total,
    required this.imported,
    required this.rejected,
    required this.rows,
    required this.errors,
  });

  /// El contrato no lista `total` en esta respuesta pero el backend lo
  /// devuelve; si faltara se calcula como importadas más rechazadas.
  factory ClinicImportResult.fromJson(Map<String, dynamic> json) {
    final imported = json['importadas'] as int;
    final rejected = json['rechazadas'] as int;
    return ClinicImportResult(
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
  final List<ClinicImportRow> rows;
  final List<ClinicImportRow> errors;
}
