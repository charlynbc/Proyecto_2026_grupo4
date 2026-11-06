/// Una fila de la carga masiva de especialidades (`Fila`, contrato #52 y
/// #53).
///
/// [number] cuenta desde 2 (la 1 es el encabezado). El nombre y el pase
/// pueden venir nulos en una fila mal formada, y [error] es nulo en toda fila
/// válida.
class SpecialtyImportRow {
  const SpecialtyImportRow({
    required this.number,
    this.name,
    this.requiresReferral,
    this.error,
  });

  factory SpecialtyImportRow.fromJson(Map<String, dynamic> json) =>
      SpecialtyImportRow(
        number: json['numero'] as int,
        name: json['nombre'] as String?,
        requiresReferral: json['requierePase'] as bool?,
        error: json['error'] as String?,
      );

  final int number;
  final String? name;
  final bool? requiresReferral;

  /// El motivo del rechazo, tal como lo manda el servidor. `null` si la fila
  /// es válida.
  final String? error;
}

List<SpecialtyImportRow> _rowsFromJson(Object? json) => [
  for (final item in json as List<dynamic>)
    SpecialtyImportRow.fromJson(item as Map<String, dynamic>),
];

/// La previsualización de la carga (contrato #52): qué filas sirven y cuáles
/// no, sin crear nada.
class SpecialtyImportPreview {
  const SpecialtyImportPreview({
    required this.total,
    required this.valid,
    required this.invalid,
    required this.rows,
    required this.errors,
  });

  factory SpecialtyImportPreview.fromJson(Map<String, dynamic> json) =>
      SpecialtyImportPreview(
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
  final List<SpecialtyImportRow> rows;

  /// Solo las filas con error.
  final List<SpecialtyImportRow> errors;
}

/// El resultado de confirmar la carga (contrato #53): éxito parcial, las
/// filas válidas se importan y las demás se rechazan con su motivo.
class SpecialtyImportResult {
  const SpecialtyImportResult({
    required this.total,
    required this.imported,
    required this.rejected,
    required this.rows,
    required this.errors,
  });

  /// El contrato no lista `total` en esta respuesta pero el backend lo
  /// devuelve; si faltara se calcula como importadas más rechazadas.
  factory SpecialtyImportResult.fromJson(Map<String, dynamic> json) {
    final imported = json['importadas'] as int;
    final rejected = json['rechazadas'] as int;
    return SpecialtyImportResult(
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
  final List<SpecialtyImportRow> rows;
  final List<SpecialtyImportRow> errors;
}
