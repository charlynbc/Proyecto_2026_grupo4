import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/files/csv_parser.dart';
import '../../../core/files/picked_csv_file.dart';
import '../models/specialty.dart';
import '../models/specialty_import.dart';
import 'specialty_import_repository.dart';
import 'specialty_repository.dart';

/// Implementación en memoria de [SpecialtyImportRepository] para
/// `USE_FAKES=true`. Lee el archivo de verdad con [parseCsv] y aplica, fila
/// por fila, las reglas del contrato #52 y #53; la primera que falla gana.
///
/// Previsualizar nunca toca el catálogo y avisa de los nombres que ya
/// existen. Confirmar repite los controles de formato y agrega al catálogo
/// una especialidad por cada fila válida; si el nombre ya existe la rechaza
/// con el mensaje del alta individual. Ninguna especialidad existente se
/// modifica.
class FakeSpecialtyImportRepository implements SpecialtyImportRepository {
  FakeSpecialtyImportRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  static const List<String> _header = ['nombre', 'requiere_pase'];
  static const int _maxNameLength = 120;

  @override
  Future<SpecialtyImportPreview> preview(PickedCsvFile file) async {
    await Future<void>.delayed(latency);
    final table = parseCsv(file.bytes, expectedHeader: _header);
    final rows = _process(table, confirm: false);
    final errors = [
      for (final row in rows)
        if (row.error != null) row,
    ];
    return SpecialtyImportPreview(
      total: rows.length,
      valid: rows.length - errors.length,
      invalid: errors.length,
      rows: rows,
      errors: errors,
    );
  }

  @override
  Future<SpecialtyImportResult> confirm(PickedCsvFile file) async {
    await Future<void>.delayed(latency);
    final table = parseCsv(file.bytes, expectedHeader: _header);
    final rows = _process(table, confirm: true);
    final errors = [
      for (final row in rows)
        if (row.error != null) row,
    ];
    return SpecialtyImportResult(
      total: rows.length,
      imported: rows.length - errors.length,
      rejected: errors.length,
      rows: rows,
      errors: errors,
    );
  }

  List<SpecialtyImportRow> _process(CsvTable table, {required bool confirm}) {
    // Nombre normalizado de las filas válidas ya vistas, con su número.
    final seen = <String, int>{};
    final result = <SpecialtyImportRow>[];
    for (var i = 0; i < table.rows.length; i++) {
      final number = i + 2;
      var row = _checkRow(number, table.rows[i], seen);
      if (row.error == null) {
        final key = FakeAdminDatabase.normalize(row.name!);
        if (_exists(key)) {
          row = _withError(
            row,
            confirm
                ? const DuplicateSpecialtyException().message
                : 'La especialidad ya existe en el sistema',
          );
        } else {
          seen[key] = number;
          if (confirm) _create(row);
        }
      }
      result.add(row);
    }
    return result;
  }

  /// Los controles de formato (pasos 1 a 5). Una fila sin error trae el
  /// nombre recortado y si requiere pase.
  SpecialtyImportRow _checkRow(
    int number,
    List<String> cells,
    Map<String, int> seen,
  ) {
    if (cells.length != _header.length) {
      return SpecialtyImportRow(
        number: number,
        error: 'La fila debe tener exactamente 2 columnas.',
      );
    }
    final name = cells[0].trim();
    final referralText = cells[1].trim().toLowerCase();

    if (name.isEmpty) {
      return SpecialtyImportRow(
        number: number,
        error: 'El nombre es obligatorio',
      );
    }
    if (name.length > _maxNameLength) {
      return SpecialtyImportRow(
        number: number,
        name: name,
        error: 'El nombre supera 120 caracteres',
      );
    }
    if (referralText.isEmpty) {
      return SpecialtyImportRow(
        number: number,
        name: name,
        error: 'La columna requiere_pase es obligatoria (si o no)',
      );
    }
    if (referralText != 'si' && referralText != 'sí' && referralText != 'no') {
      return SpecialtyImportRow(
        number: number,
        name: name,
        error: 'requiere_pase debe ser si o no',
      );
    }
    final requiresReferral = referralText != 'no';

    final first = seen[FakeAdminDatabase.normalize(name)];
    if (first != null) {
      return SpecialtyImportRow(
        number: number,
        name: name,
        requiresReferral: requiresReferral,
        error: 'Nombre duplicado. Primera aparición válida en fila $first',
      );
    }
    return SpecialtyImportRow(
      number: number,
      name: name,
      requiresReferral: requiresReferral,
    );
  }

  SpecialtyImportRow _withError(SpecialtyImportRow row, String error) =>
      SpecialtyImportRow(
        number: row.number,
        name: row.name,
        requiresReferral: row.requiresReferral,
        error: error,
      );

  bool _exists(String normalizedName) => _db.specialties.any(
    (s) => FakeAdminDatabase.normalize(s.name) == normalizedName,
  );

  void _create(SpecialtyImportRow row) {
    _db.specialties.add(
      Specialty(
        id: _db.newSpecialtyId(),
        name: row.name!,
        requiresReferral: row.requiresReferral!,
      ),
    );
  }
}
