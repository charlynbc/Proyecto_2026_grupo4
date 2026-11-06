import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/files/csv_parser.dart';
import '../../../core/files/picked_csv_file.dart';
import '../models/clinic.dart';
import '../models/clinic_import.dart';
import 'clinic_import_repository.dart';

/// Implementación en memoria de [ClinicImportRepository] para
/// `USE_FAKES=true`. Lee el archivo de verdad con [parseCsv] y aplica, fila
/// por fila, las reglas del contrato #56 y #57 en el orden del servidor
/// (`ConsultorioCsvValidador`); la primera que falla gana.
///
/// Previsualizar nunca toca los consultorios. Confirmar repite todo y agrega
/// al catálogo uno por cada fila válida. Ninguno existente se modifica.
///
/// Como el servidor, el nombre cuenta como "visto" para detectar repetidos
/// aunque esa fila después se rechace porque ya existe.
class FakeClinicImportRepository implements ClinicImportRepository {
  FakeClinicImportRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  static const List<String> _header = ['nombre', 'ubicacion'];
  static const int _maxNameLength = 120;
  static const int _maxLocationLength = 200;

  @override
  Future<ClinicImportPreview> preview(PickedCsvFile file) async {
    await Future<void>.delayed(latency);
    final table = parseCsv(file.bytes, expectedHeader: _header);
    final rows = _process(table, confirm: false);
    final errors = [
      for (final row in rows)
        if (row.error != null) row,
    ];
    return ClinicImportPreview(
      total: rows.length,
      valid: rows.length - errors.length,
      invalid: errors.length,
      rows: rows,
      errors: errors,
    );
  }

  @override
  Future<ClinicImportResult> confirm(PickedCsvFile file) async {
    await Future<void>.delayed(latency);
    final table = parseCsv(file.bytes, expectedHeader: _header);
    final rows = _process(table, confirm: true);
    final errors = [
      for (final row in rows)
        if (row.error != null) row,
    ];
    return ClinicImportResult(
      total: rows.length,
      imported: rows.length - errors.length,
      rejected: errors.length,
      rows: rows,
      errors: errors,
    );
  }

  List<ClinicImportRow> _process(CsvTable table, {required bool confirm}) {
    // Nombre normalizado de las filas con formato válido ya vistas, con su
    // número.
    final seen = <String, int>{};
    final result = <ClinicImportRow>[];
    for (var i = 0; i < table.rows.length; i++) {
      final number = i + 2;
      var row = _checkRow(number, table.rows[i], seen);
      if (row.error == null &&
          _exists(FakeAdminDatabase.normalize(row.name!))) {
        row = ClinicImportRow(
          number: row.number,
          name: row.name,
          location: row.location,
          error: 'El consultorio ya existe en el sistema',
        );
      }
      if (row.error == null && confirm) _create(row);
      result.add(row);
    }
    return result;
  }

  /// Los controles de formato y de repetidos dentro del archivo. Una fila sin
  /// error trae el nombre y la ubicación recortados.
  ClinicImportRow _checkRow(
    int number,
    List<String> cells,
    Map<String, int> seen,
  ) {
    if (cells.length != _header.length) {
      return ClinicImportRow(
        number: number,
        error: 'La fila debe tener exactamente 2 columnas',
      );
    }
    final name = cells[0].trim();
    final location = cells[1].trim();
    final shownName = name.isEmpty ? null : name;
    final shownLocation = location.isEmpty ? null : location;

    ClinicImportRow fail(String error) => ClinicImportRow(
      number: number,
      name: shownName,
      location: shownLocation,
      error: error,
    );

    if (name.isEmpty) return fail('El nombre es obligatorio');
    if (location.isEmpty) return fail('La ubicación es obligatoria');
    if (name.length > _maxNameLength) {
      return fail('El nombre supera 120 caracteres');
    }
    if (location.length > _maxLocationLength) {
      return fail('La ubicación supera 200 caracteres');
    }

    final key = FakeAdminDatabase.normalize(name);
    final first = seen[key];
    if (first != null) {
      return fail('Nombre duplicado. Primera aparición válida en fila $first');
    }
    seen[key] = number;
    return ClinicImportRow(number: number, name: name, location: location);
  }

  bool _exists(String normalizedName) => _db.clinics.any(
    (c) => FakeAdminDatabase.normalize(c.name) == normalizedName,
  );

  void _create(ClinicImportRow row) {
    _db.clinics.add(
      Clinic(id: _db.newClinicId(), name: row.name!, location: row.location!),
    );
  }
}
