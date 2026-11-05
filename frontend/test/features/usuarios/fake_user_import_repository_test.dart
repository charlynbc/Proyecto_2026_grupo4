import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/models/user_import.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/user_import_csv.dart';

final _now = DateTime.utc(2026, 11, 5, 12);

(FakeAdminDatabase, FakeUserImportRepository) _env() {
  final db = FakeAdminDatabase(clock: () => _now);
  return (db, FakeUserImportRepository(db, latency: Duration.zero));
}

/// Un archivo con el encabezado y las [rows] dadas.
String _csv(List<String> rows) => '$kUserImportHeader\n${rows.join('\n')}\n';

/// Número de fila y mensaje de las filas con error.
Map<int, String?> _errors(List<UserImportRow> rows) => {
  for (final row in rows) row.number: row.error,
};

const _staffDuplicate =
    'Esa cédula ya tiene una cuenta de empleado habilitada o pendiente de '
    'activar. Para darle otro rol, inactivá primero la cuenta anterior.';
const _mismatch =
    'Esa cédula ya está registrada con otro nombre, apellido o fecha de '
    'nacimiento. Corregí primero esos datos del padrón y volvé a intentar.';

void main() {
  group('previsualizar el archivo de prueba', () {
    test('da 11 filas, 3 válidas y 8 con error', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(userImportFile());

      expect(preview.total, 11);
      expect(preview.valid, 3);
      expect(preview.invalid, 8);
      expect(preview.rows.map((r) => r.number), [
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ]);
      expect(preview.rows.where((r) => r.error == null).map((r) => r.number), [
        2,
        3,
        6,
      ]);
    });

    test('cada fila con error trae su motivo', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(userImportFile());

      expect(_errors(preview.errors), {
        4: 'La CI no es valida',
        5: 'La CI ya tiene una cuenta de socio',
        7: 'La CI ya tiene una cuenta de empleado habilitada',
        8: 'La CI ya esta registrada con otros datos personales',
        9: 'Especialidad desconocida: Oncología',
        10: 'El correo no tiene un formato valido',
        11: 'Fila repetida (misma CI y rol). Primera aparición válida en fila 2',
        12: 'fecha_nacimiento debe tener formato aaaa-mm-dd',
      });
    });

    test('las filas traen sus datos, con el rol en mayúsculas', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(userImportFile());

      final marcos = preview.rows.firstWhere((r) => r.number == 3);
      expect(marcos.ci, '30000026');
      expect(marcos.firstName, 'Marcos');
      expect(marcos.lastName, 'Gil');
      expect(marcos.role, 'MEDICO');
      expect(marcos.error, isNull);
      final sara = preview.errors.firstWhere((r) => r.number == 4);
      expect(sara.ci, '30000033');
      expect(sara.firstName, 'Sara');
      expect(sara.lastName, 'Lima');
      expect(sara.role, 'SOCIO');
    });

    test('no modifica el padrón', () async {
      final (db, repository) = _env();
      final before = db.accounts.length;

      await repository.preview(userImportFile());

      expect(db.accounts.length, before);
    });
  });

  group('confirmar el archivo de prueba', () {
    test(
      'importa 3 y rechaza 8, con los mensajes del alta individual',
      () async {
        final (_, repository) = _env();

        final result = await repository.confirm(userImportFile());

        expect(result.total, 11);
        expect(result.imported, 3);
        expect(result.rejected, 8);
        expect(_errors(result.errors), {
          4: 'La CI no es valida',
          5: 'Esa cédula ya tiene una cuenta de socio.',
          7: _staffDuplicate,
          8: _mismatch,
          9: 'Especialidad desconocida: Oncología',
          10: 'El correo no tiene un formato valido',
          11: 'Fila repetida (misma CI y rol). Primera aparición válida en fila 2',
          12: 'fecha_nacimiento debe tener formato aaaa-mm-dd',
        });
      },
    );

    test('agrega 3 cuentas sin activar al padrón', () async {
      final (db, repository) = _env();
      final before = db.accounts.length;

      await repository.confirm(userImportFile());

      expect(db.accounts.length, before + 3);
      final added = db.accounts.sublist(before);
      expect(added.map((a) => a.ci), ['30000010', '30000026', '12345672']);
      expect(added.map((a) => a.role), [
        UserRole.socio,
        UserRole.medico,
        UserRole.funcionario,
      ]);
      expect(added.map((a) => a.activated), [false, false, false]);
      expect(added.map((a) => a.status), [
        AccountStatus.active,
        AccountStatus.active,
        AccountStatus.active,
      ]);
      expect(added.map((a) => a.createdAt), [_now, _now, _now]);
      expect(added.map((a) => a.email), [
        'julia.ferrari@example.org',
        'marcos.gil@example.org',
        'ana.rodriguez@example.org',
      ]);
      expect(added[0].birthDate, DateTime.utc(1992, 3, 15));
      expect(added[0].firstName, 'Julia');
      expect(added[0].lastName, 'Ferrari');
    });

    test('las especialidades del médico se guardan como ids', () async {
      final (db, repository) = _env();

      await repository.confirm(userImportFile());

      final marcos = db.accounts.firstWhere((a) => a.ci == '30000026');
      // Cardiología es la 2 y Dermatología la 3 en los datos sembrados.
      expect(marcos.specialtyIds, [2, 3]);
      final julia = db.accounts.firstWhere((a) => a.ci == '30000010');
      expect(julia.specialtyIds, isEmpty);
    });

    test('repetir la confirmación no crea cuentas duplicadas', () async {
      final (db, repository) = _env();
      await repository.confirm(userImportFile());
      final after = db.accounts.length;

      final second = await repository.confirm(userImportFile());

      expect(db.accounts.length, after);
      expect(second.imported, 0);
      expect(second.rejected, 11);
    });
  });

  group('reglas por fila', () {
    test(
      'una fila con otra cantidad de celdas deja los datos en nulo',
      () async {
        final (_, repository) = _env();

        final preview = await repository.preview(
          csvFile(_csv(['30000010,Julia,Ferrari'])),
        );

        final row = preview.errors.single;
        expect(row.number, 2);
        expect(row.error, 'La fila debe tener exactamente 10 columnas.');
        expect(row.ci, isNull);
        expect(row.firstName, isNull);
        expect(row.lastName, isNull);
        expect(row.role, isNull);
      },
    );

    test('falta un campo obligatorio, aun con espacios', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          _csv([
            '30000010,   ,Ferrari,1992-03-15,julia@example.org,099111222,,,SOCIO,',
          ]),
        ),
      );

      expect(
        preview.errors.single.error,
        'Falta un campo obligatorio (ci, nombre, apellido, fecha_nacimiento, '
        'correo, telefono_1, rol)',
      );
    });

    test('la CI admite puntos y guion y queda normalizada', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          _csv([
            '3.000.001-0,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,SOCIO,',
          ]),
        ),
      );

      expect(preview.valid, 1);
      expect(preview.rows.single.ci, '30000010');
    });

    test('una CI inválida queda normalizada en la fila', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          _csv([
            '3.000.003-3,Sara,Lima,1991-04-04,sara@example.org,099121212,,,SOCIO,',
          ]),
        ),
      );

      expect(preview.errors.single.error, 'La CI no es valida');
      expect(preview.errors.single.ci, '30000033');
    });

    test('un rol que no existe', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          _csv([
            '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,JEFE,',
          ]),
        ),
      );

      expect(preview.errors.single.error, 'El rol indicado no es valido');
      expect(preview.errors.single.role, 'JEFE');
    });

    test('un médico sin especialidades', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          _csv([
            '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,MEDICO,',
          ]),
        ),
      );

      expect(
        preview.errors.single.error,
        'Un medico requiere al menos una especialidad',
      );
    });

    test('un rol que no es médico con especialidades', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          _csv([
            '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,SOCIO,Cardiología',
          ]),
        ),
      );

      expect(
        preview.errors.single.error,
        'Las especialidades solo corresponden a medicos',
      );
    });

    test('las especialidades no distinguen mayúsculas', () async {
      final (db, repository) = _env();

      final result = await repository.confirm(
        csvFile(
          _csv([
            '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,MEDICO,CARDIOLOGÍA|medicina general',
          ]),
        ),
      );

      expect(result.imported, 1);
      expect(db.accounts.last.specialtyIds, [2, 1]);
    });

    test('acepta punto y coma como separador', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        csvFile(
          '${kUserImportHeader.replaceAll(',', ';')}\n'
          '30000010;Julia;Ferrari;1992-03-15;julia@example.org;099111222;;;SOCIO;\n',
        ),
      );

      expect(preview.valid, 1);
    });

    test('una cuenta de empleado inactiva no impide otra', () async {
      final (db, repository) = _env();
      db.accounts.add(
        FakeAccount(
          id: db.newAccountId(),
          ci: '30000026',
          firstName: 'Marcos',
          lastName: 'Gil',
          birthDate: DateTime.utc(1980, 7, 2),
          email: 'marcos.gil@example.org',
          role: UserRole.medico,
          status: AccountStatus.inactive,
          createdAt: _now,
        ),
      );

      final preview = await repository.preview(
        csvFile(
          _csv([
            '30000026,Marcos,Gil,1980-07-02,marcos.gil@example.org,099333444,,,FUNCIONARIO,',
          ]),
        ),
      );

      expect(preview.valid, 1);
      expect(preview.errors, isEmpty);
    });

    test(
      'la misma persona con dos roles distintos no es una repetida',
      () async {
        final (_, repository) = _env();

        final preview = await repository.preview(
          csvFile(
            _csv([
              '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,SOCIO,',
              '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,FUNCIONARIO,',
            ]),
          ),
        );

        expect(preview.valid, 2);
      },
    );
  });

  group('el archivo no sirve', () {
    test('con un encabezado equivocado lanza CsvFormatException', () async {
      final (_, repository) = _env();

      await expectLater(
        repository.preview(csvFile('ci,nombre\n1,2\n')),
        throwsA(
          isA<CsvFormatException>().having(
            (e) => e.message,
            'message',
            'El CSV debe tener exactamente las columnas: $kUserImportHeader',
          ),
        ),
      );
      await expectLater(
        repository.confirm(csvFile('ci,nombre\n1,2\n')),
        throwsA(isA<CsvFormatException>()),
      );
    });

    test('con más de 1000 filas lanza el error de filas', () async {
      final (db, repository) = _env();
      final before = db.accounts.length;
      final rows = List.filled(
        1001,
        '30000010,Julia,Ferrari,1992-03-15,julia@example.org,099111222,,,SOCIO,',
      );

      await expectLater(
        repository.confirm(csvFile(_csv(rows))),
        throwsA(
          isA<CsvFormatException>().having(
            (e) => e.message,
            'message',
            'El archivo supera el máximo de 1000 filas de datos',
          ),
        ),
      );
      expect(db.accounts.length, before);
    });
  });
}
