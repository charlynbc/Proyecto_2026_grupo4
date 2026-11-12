import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/files/csv_parser.dart';
import '../../../core/files/picked_csv_file.dart';
import '../../../core/validators/uruguayan_ci_validator.dart';
import '../../auth/models/user_role.dart';
import '../models/user_account.dart';
import '../models/user_import.dart';
import 'user_import_repository.dart';
import 'user_repository.dart';

/// Implementación en memoria de [UserImportRepository] para
/// `USE_FAKES=true`. Lee el archivo de verdad con [parseCsv] y aplica, fila
/// por fila, las reglas del contrato #54 y #55; la primera que falla gana.
///
/// Previsualizar nunca toca el padrón. Confirmar repite todo y crea, en el
/// padrón, una cuenta sin activar por cada fila válida; los rechazos que
/// dependen de la base usan, como el servidor, los mensajes del alta
/// individual. Cada fila de confirmar ve las cuentas que crearon las
/// anteriores, como si fueran altas sueltas. No valida largos de campos.
class FakeUserImportRepository implements UserImportRepository {
  FakeUserImportRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  static const String _missingField =
      'Falta un campo obligatorio (ci, nombre, apellido, fecha_nacimiento, '
      'correo, telefono_1, rol)';

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  @override
  Future<UserImportPreview> preview(PickedCsvFile file) async {
    await Future<void>.delayed(latency);
    final table = parseCsv(file.bytes, expectedHeader: kUserImportColumns);
    final rows = _process(table, confirm: false);
    final errors = [
      for (final row in rows)
        if (row.error != null) row,
    ];
    return UserImportPreview(
      total: rows.length,
      valid: rows.length - errors.length,
      invalid: errors.length,
      rows: rows,
      errors: errors,
    );
  }

  @override
  Future<UserImportResult> confirm(PickedCsvFile file) async {
    await Future<void>.delayed(latency);
    final table = parseCsv(file.bytes, expectedHeader: kUserImportColumns);
    final rows = _process(table, confirm: true);
    final errors = [
      for (final row in rows)
        if (row.error != null) row,
    ];
    return UserImportResult(
      total: rows.length,
      imported: rows.length - errors.length,
      rejected: errors.length,
      rows: rows,
      errors: errors,
    );
  }

  List<UserImportRow> _process(CsvTable table, {required bool confirm}) {
    // Cuenta y rol de las filas válidas ya vistas, con el número de fila.
    final seen = <String, int>{};
    final result = <UserImportRow>[];
    for (var i = 0; i < table.rows.length; i++) {
      final number = i + 2;
      final checked = _checkRow(number, table.rows[i], seen);
      var row = checked.row;
      final candidate = checked.candidate;
      if (candidate != null) {
        final error = _databaseError(candidate, confirm: confirm);
        if (error != null) {
          row = UserImportRow(
            number: row.number,
            ci: row.ci,
            firstName: row.firstName,
            lastName: row.lastName,
            role: row.role,
            error: error,
          );
        } else {
          seen['${candidate.ci}|${candidate.role.apiValue}'] = number;
          if (confirm) _create(candidate);
        }
      }
      result.add(row);
    }
    return result;
  }

  /// Los controles que no necesitan la base (pasos 1 a 8). Si la fila pasa,
  /// trae también sus datos ya interpretados.
  ({UserImportRow row, _Candidate? candidate}) _checkRow(
    int number,
    List<String> cells,
    Map<String, int> seen,
  ) {
    if (cells.length != kUserImportColumns.length) {
      return (
        row: UserImportRow(
          number: number,
          error: 'La fila debe tener exactamente 10 columnas.',
        ),
        candidate: null,
      );
    }
    final values = [for (final cell in cells) cell.trim()];
    String? orNull(String text) => text.isEmpty ? null : text;

    var ci = orNull(values[0]);
    final firstName = orNull(values[1]);
    final lastName = orNull(values[2]);
    final role = UserRole.tryParse(values[8].toUpperCase());
    final roleText = role?.apiValue ?? orNull(values[8]);

    ({UserImportRow row, _Candidate? candidate}) fail(String error) => (
      row: UserImportRow(
        number: number,
        ci: ci,
        firstName: firstName,
        lastName: lastName,
        role: roleText,
        error: error,
      ),
      candidate: null,
    );

    const requiredColumns = [0, 1, 2, 3, 4, 5, 8];
    if (requiredColumns.any((index) => values[index].isEmpty)) {
      return fail(_missingField);
    }

    ci = values[0].replaceAll(RegExp(r'[.\-]'), '');
    if (!isValidUruguayanCi(ci)) return fail('La CI no es valida');

    if (!_email.hasMatch(values[4])) {
      return fail('El correo no tiene un formato valido');
    }
    if (role == null) return fail('El rol indicado no es valido');

    final birthDate = _parseDate(values[3]);
    if (birthDate == null) {
      return fail('fecha_nacimiento debe tener formato aaaa-mm-dd');
    }

    final specialtyNames = [
      for (final name in values[9].split('|'))
        if (name.trim().isNotEmpty) name.trim(),
    ];
    if (role == UserRole.medico && specialtyNames.isEmpty) {
      return fail('Un medico requiere al menos una especialidad');
    }
    if (role != UserRole.medico && specialtyNames.isNotEmpty) {
      return fail('Las especialidades solo corresponden a medicos');
    }

    final first = seen['$ci|${role.apiValue}'];
    if (first != null) {
      return fail(
        'Fila repetida (misma CI y rol). Primera aparición válida en fila '
        '$first',
      );
    }

    final candidate = _Candidate(
      ci: ci,
      firstName: values[1],
      lastName: values[2],
      birthDate: birthDate,
      email: values[4],
      role: role,
      specialtyNames: specialtyNames,
    );
    return (
      row: UserImportRow(
        number: number,
        ci: ci,
        firstName: firstName,
        lastName: lastName,
        role: roleText,
      ),
      candidate: candidate,
    );
  }

  /// `aaaa-mm-dd` de una fecha que existe en el calendario, o `null`.
  DateTime? _parseDate(String text) {
    final match = _date.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    final exists = date.year == year && date.month == month && date.day == day;
    return exists ? date : null;
  }

  /// Los controles contra el padrón (paso 9), o `null` si la fila sirve. Al
  /// confirmar, los motivos son los mensajes del alta individual.
  String? _databaseError(_Candidate candidate, {required bool confirm}) {
    for (final name in candidate.specialtyNames) {
      if (_specialtyId(name) == null) return 'Especialidad desconocida: $name';
    }

    final sameCi = _db.accounts.where((a) => a.ci == candidate.ci).toList();
    if (sameCi.isNotEmpty) {
      final known = sameCi.first;
      final sameBirthDate =
          known.birthDate.year == candidate.birthDate.year &&
          known.birthDate.month == candidate.birthDate.month &&
          known.birthDate.day == candidate.birthDate.day;
      if (known.firstName != candidate.firstName ||
          known.lastName != candidate.lastName ||
          !sameBirthDate) {
        return confirm
            ? const MismatchedPersonDataException().message
            : 'La CI ya esta registrada con otros datos personales';
      }
    }

    if (candidate.role == UserRole.socio) {
      if (sameCi.any((a) => a.role == UserRole.socio)) {
        return confirm
            ? const DuplicateMemberException().message
            : 'La CI ya tiene una cuenta de socio';
      }
    } else if (sameCi.any(
      (a) => a.role != UserRole.socio && a.status == AccountStatus.active,
    )) {
      return confirm
          ? const DuplicateStaffException().message
          : 'La CI ya tiene una cuenta de empleado habilitada';
    }
    return null;
  }

  int? _specialtyId(String name) {
    final key = FakeAdminDatabase.normalize(name);
    for (final specialty in _db.specialties) {
      if (FakeAdminDatabase.normalize(specialty.name) == key) {
        return specialty.id;
      }
    }
    return null;
  }

  void _create(_Candidate candidate) {
    _db.accounts.add(
      FakeAccount(
        id: _db.newAccountId(),
        ci: candidate.ci,
        firstName: candidate.firstName,
        lastName: candidate.lastName,
        birthDate: candidate.birthDate,
        email: candidate.email,
        role: candidate.role,
        activated: false,
        createdAt: _db.clock().toUtc(),
        specialtyIds: candidate.role == UserRole.medico
            ? {for (final name in candidate.specialtyNames) _specialtyId(name)!}
                  .toList()
            : const [],
      ),
    );
  }
}

/// Los datos de una fila que pasó los controles de formato.
class _Candidate {
  const _Candidate({
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.email,
    required this.role,
    required this.specialtyNames,
  });

  final String ci;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String email;
  final UserRole role;
  final List<String> specialtyNames;
}
