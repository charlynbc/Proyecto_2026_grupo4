import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_import.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/specialty_import_csv.dart';

(FakeAdminDatabase, FakeSpecialtyImportRepository) _env() {
  final db = FakeAdminDatabase();
  return (db, FakeSpecialtyImportRepository(db, latency: Duration.zero));
}

/// Un archivo con el encabezado y las [rows] dadas.
String _csv(List<String> rows) =>
    '$kSpecialtyImportHeader\n${rows.join('\n')}\n';

/// Número de fila y mensaje de las filas con error.
Map<int, String?> _errors(List<SpecialtyImportRow> rows) => {
  for (final row in rows) row.number: row.error,
};

void main() {
  group('previsualizar el archivo de prueba', () {
    test('da 7 filas, 3 válidas y 4 con error', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(specialtyImportFile());

      expect(preview.total, 7);
      expect(preview.valid, 3);
      expect(preview.invalid, 4);
      expect(preview.rows.map((r) => r.number), [2, 3, 4, 5, 6, 7, 8]);
      expect(preview.rows.where((r) => r.error == null).map((r) => r.number), [
        2,
        5,
        8,
      ]);
      expect(preview.rows.where((r) => r.error == null).map((r) => r.name), [
        'Neurología',
        'Pediatría',
        'Oftalmología',
      ]);
      expect(
        preview.rows
            .where((r) => r.error == null)
            .map((r) => r.requiresReferral),
        [true, false, false],
      );
    });

    test('cada fila con error trae su motivo', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(specialtyImportFile());

      expect(_errors(preview.errors), {
        3: 'requiere_pase debe ser si o no',
        4: 'La especialidad ya existe en el sistema',
        6: 'Nombre duplicado. Primera aparición válida en fila 5',
        7: 'El nombre es obligatorio',
      });
    });

    test('las filas con error traen el nombre cuando lo hay', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(specialtyImportFile());

      expect(preview.errors.map((r) => r.name), [
        'Traumatología',
        'Cardiología',
        'Pediatría',
        null,
      ]);
    });

    test('no modifica el catálogo', () async {
      final (db, repository) = _env();
      final before = db.specialties.length;

      await repository.preview(specialtyImportFile());

      expect(db.specialties.length, before);
      expect(before, 3);
    });
  });

  group('confirmar el archivo de prueba', () {
    test('importa 3 y rechaza 4, con "ya existe" en la fila 4', () async {
      final (_, repository) = _env();

      final result = await repository.confirm(specialtyImportFile());

      expect(result.total, 7);
      expect(result.imported, 3);
      expect(result.rejected, 4);
      expect(_errors(result.errors), {
        3: 'requiere_pase debe ser si o no',
        4: 'Ya existe una especialidad registrada con ese nombre.',
        6: 'Nombre duplicado. Primera aparición válida en fila 5',
        7: 'El nombre es obligatorio',
      });
    });

    test('el catálogo pasa de 3 a 6 especialidades', () async {
      final (db, repository) = _env();

      await repository.confirm(specialtyImportFile());

      expect(db.specialties.length, 6);
      final added = db.specialties.skip(3).toList();
      expect(added.map((s) => s.name), [
        'Neurología',
        'Pediatría',
        'Oftalmología',
      ]);
      expect(added.map((s) => s.requiresReferral), [true, false, false]);
      expect(added.map((s) => s.id), [4, 5, 6]);
    });

    test('no modifica las especialidades que ya existían', () async {
      final (db, repository) = _env();

      await repository.confirm(specialtyImportFile());

      final cardiology = db.specialties.firstWhere(
        (s) => s.name == 'Cardiología',
      );
      expect(cardiology.requiresReferral, isTrue);
      expect(
        db.specialties.where((s) => s.name == 'Cardiología'),
        hasLength(1),
      );
    });

    test('repetir la confirmación no crea especialidades duplicadas', () async {
      final (db, repository) = _env();
      await repository.confirm(specialtyImportFile());

      final second = await repository.confirm(specialtyImportFile());

      expect(db.specialties.length, 6);
      expect(second.imported, 0);
      expect(second.rejected, 7);
    });
  });

  group('reglas por fila', () {
    test(
      'una fila con otra cantidad de celdas deja nombre y pase en nulo',
      () async {
        final (_, repository) = _env();

        final preview = await repository.preview(
          specialtyCsvFile(_csv(['Neurología'])),
        );

        final row = preview.errors.single;
        expect(row.number, 2);
        expect(row.error, 'La fila debe tener exactamente 2 columnas.');
        expect(row.name, isNull);
        expect(row.requiresReferral, isNull);
      },
    );

    test('un nombre solo de espacios es obligatorio', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        specialtyCsvFile(_csv(['   ,si'])),
      );

      expect(preview.errors.single.error, 'El nombre es obligatorio');
    });

    test(
      'un nombre de 121 caracteres supera el límite y uno de 120 pasa',
      () async {
        final (_, repository) = _env();
        final long = 'a' * 121;
        final limit = 'b' * 120;

        final preview = await repository.preview(
          specialtyCsvFile(_csv(['$long,si', '$limit,si'])),
        );

        expect(_errors(preview.errors), {2: 'El nombre supera 120 caracteres'});
        expect(preview.rows.last.error, isNull);
        expect(preview.valid, 1);
      },
    );

    test('requiere_pase vacío es obligatorio', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        specialtyCsvFile(_csv(['Neurología,', 'Pediatría,  '])),
      );

      expect(_errors(preview.errors), {
        2: 'La columna requiere_pase es obligatoria (si o no)',
        3: 'La columna requiere_pase es obligatoria (si o no)',
      });
    });

    test(
      'requiere_pase acepta si, sí y no sin distinguir mayúsculas',
      () async {
        final (_, repository) = _env();

        final preview = await repository.preview(
          specialtyCsvFile(
            _csv([
              'Neurología,SÍ',
              'Pediatría,Si',
              'Oftalmología,NO',
              'Urología,sí',
            ]),
          ),
        );

        expect(preview.errors, isEmpty);
        expect(preview.rows.map((r) => r.requiresReferral), [
          true,
          true,
          false,
          true,
        ]);
      },
    );

    test('el duplicado dentro del archivo no distingue mayúsculas', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        specialtyCsvFile(_csv(['Neurología,si', 'NEUROLOGÍA,no'])),
      );

      expect(_errors(preview.errors), {
        3: 'Nombre duplicado. Primera aparición válida en fila 2',
      });
    });

    test('"ya existe" tampoco distingue mayúsculas ni espacios', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        specialtyCsvFile(_csv(['  CARDIOLOGÍA ,si'])),
      );

      expect(_errors(preview.errors), {
        2: 'La especialidad ya existe en el sistema',
      });
    });

    test('guarda el nombre recortado', () async {
      final (db, repository) = _env();

      await repository.confirm(specialtyCsvFile(_csv(['  Neurología  ,si'])));

      expect(db.specialties.last.name, 'Neurología');
    });

    test('acepta punto y coma como separador', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        specialtyCsvFile('nombre;requiere_pase\nNeurología;si\n'),
      );

      expect(preview.valid, 1);
    });
  });

  group('el archivo no sirve', () {
    test('con un encabezado equivocado lanza CsvFormatException', () async {
      final (_, repository) = _env();

      await expectLater(
        repository.preview(specialtyCsvFile('nombre,otra\nA,si\n')),
        throwsA(
          isA<CsvFormatException>().having(
            (e) => e.message,
            'message',
            'El CSV debe tener exactamente las columnas: nombre,requiere_pase',
          ),
        ),
      );
      await expectLater(
        repository.confirm(specialtyCsvFile('nombre,otra\nA,si\n')),
        throwsA(isA<CsvFormatException>()),
      );
    });

    test('con más de 1000 filas lanza el error de filas', () async {
      final (db, repository) = _env();
      final rows = [for (var i = 0; i < 1001; i++) 'Especialidad $i,si'];

      await expectLater(
        repository.confirm(specialtyCsvFile(_csv(rows))),
        throwsA(
          isA<CsvFormatException>().having(
            (e) => e.message,
            'message',
            'El archivo supera el máximo de 1000 filas de datos',
          ),
        ),
      );
      expect(db.specialties.length, 3);
    });
  });
}
