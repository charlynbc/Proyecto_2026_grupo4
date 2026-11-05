import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_import.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_import_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/clinic_import_csv.dart';

(FakeAdminDatabase, FakeClinicImportRepository) _env() {
  final db = FakeAdminDatabase();
  return (db, FakeClinicImportRepository(db, latency: Duration.zero));
}

/// Un archivo con el encabezado y las [rows] dadas.
String _csv(List<String> rows) => '$kClinicImportHeader\n${rows.join('\n')}\n';

/// Número de fila y mensaje de las filas con error.
Map<int, String?> _errors(List<ClinicImportRow> rows) => {
  for (final row in rows) row.number: row.error,
};

void main() {
  group('previsualizar el archivo de prueba', () {
    test('da 7 filas, 2 válidas y 5 con error', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(clinicImportFile());

      expect(preview.total, 7);
      expect(preview.valid, 2);
      expect(preview.invalid, 5);
      expect(preview.rows.map((r) => r.number), [2, 3, 4, 5, 6, 7, 8]);
      final valid = preview.rows.where((r) => r.error == null).toList();
      expect(valid.map((r) => r.number), [2, 7]);
      expect(valid.map((r) => r.name), ['Consultorio 20', 'Consultorio 22']);
      expect(valid.map((r) => r.location), ['Piso 3', 'Subsuelo']);
    });

    test('cada fila con error trae su motivo', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(clinicImportFile());

      expect(_errors(preview.errors), {
        3: 'El consultorio ya existe en el sistema',
        4: 'La ubicación es obligatoria',
        5: 'Nombre duplicado. Primera aparición válida en fila 2',
        6: 'El nombre es obligatorio',
        8: 'El consultorio ya existe en el sistema',
      });
    });

    test('las filas con error traen los datos que tienen', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(clinicImportFile());

      expect(preview.errors.map((r) => r.name), [
        'Consultorio 7',
        'Consultorio 21',
        'Consultorio 20',
        null,
        'consultorio 12',
      ]);
      expect(preview.errors.map((r) => r.location), [
        'Piso 1',
        null,
        'Piso 4',
        'Planta baja',
        'Piso 2',
      ]);
    });

    test('no modifica los consultorios', () async {
      final (db, repository) = _env();

      await repository.preview(clinicImportFile());

      expect(db.clinics.length, 3);
    });
  });

  group('confirmar el archivo de prueba', () {
    test('importa 2 y rechaza 5, con los mismos motivos', () async {
      final (_, repository) = _env();

      final result = await repository.confirm(clinicImportFile());

      expect(result.total, 7);
      expect(result.imported, 2);
      expect(result.rejected, 5);
      expect(_errors(result.errors), {
        3: 'El consultorio ya existe en el sistema',
        4: 'La ubicación es obligatoria',
        5: 'Nombre duplicado. Primera aparición válida en fila 2',
        6: 'El nombre es obligatorio',
        8: 'El consultorio ya existe en el sistema',
      });
    });

    test('pasa de 3 a 5 consultorios', () async {
      final (db, repository) = _env();

      await repository.confirm(clinicImportFile());

      expect(db.clinics.length, 5);
      final added = db.clinics.skip(3).toList();
      expect(added.map((c) => c.name), ['Consultorio 20', 'Consultorio 22']);
      expect(added.map((c) => c.location), ['Piso 3', 'Subsuelo']);
      expect(added.map((c) => c.id), [4, 5]);
    });

    test('no modifica los consultorios que ya existían', () async {
      final (db, repository) = _env();

      await repository.confirm(clinicImportFile());

      final seven = db.clinics.firstWhere((c) => c.name == 'Consultorio 7');
      expect(seven.location, 'Piso 1');
      final twelve = db.clinics.firstWhere((c) => c.id == 3);
      expect(twelve.name, 'Consultorio 12');
      expect(twelve.location, 'Piso 2');
    });

    test('repetir la confirmación no crea consultorios duplicados', () async {
      final (db, repository) = _env();
      await repository.confirm(clinicImportFile());

      final second = await repository.confirm(clinicImportFile());

      expect(db.clinics.length, 5);
      expect(second.imported, 0);
      expect(second.rejected, 7);
    });
  });

  group('reglas por fila', () {
    test(
      'una fila con otra cantidad de celdas deja los datos en nulo',
      () async {
        final (_, repository) = _env();

        final preview = await repository.preview(
          clinicCsvFile(_csv(['Consultorio 20'])),
        );

        final row = preview.errors.single;
        expect(row.number, 2);
        expect(row.error, 'La fila debe tener exactamente 2 columnas');
        expect(row.name, isNull);
        expect(row.location, isNull);
      },
    );

    test('un nombre solo de espacios es obligatorio', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile(_csv(['   ,Piso 3'])),
      );

      expect(preview.errors.single.error, 'El nombre es obligatorio');
    });

    test('una ubicación vacía o de espacios es obligatoria', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile(_csv(['Consultorio 20,', 'Consultorio 21,   '])),
      );

      expect(_errors(preview.errors), {
        2: 'La ubicación es obligatoria',
        3: 'La ubicación es obligatoria',
      });
    });

    test(
      'un nombre de 121 caracteres supera el límite y uno de 120 pasa',
      () async {
        final (_, repository) = _env();
        final long = 'a' * 121;
        final limit = 'b' * 120;

        final preview = await repository.preview(
          clinicCsvFile(_csv(['$long,Piso 3', '$limit,Piso 3'])),
        );

        expect(_errors(preview.errors), {2: 'El nombre supera 120 caracteres'});
        expect(preview.rows.last.error, isNull);
        expect(preview.valid, 1);
      },
    );

    test(
      'una ubicación de 201 caracteres supera el límite y una de 200 pasa',
      () async {
        final (_, repository) = _env();
        final long = 'a' * 201;
        final limit = 'b' * 200;

        final preview = await repository.preview(
          clinicCsvFile(
            _csv(['Consultorio 20,$long', 'Consultorio 21,$limit']),
          ),
        );

        expect(_errors(preview.errors), {
          2: 'La ubicación supera 200 caracteres',
        });
        expect(preview.rows.last.error, isNull);
      },
    );

    test('como en el servidor, la ubicación vacía se avisa antes que el largo del nombre', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile(_csv(['${'a' * 121},'])),
      );

      expect(preview.errors.single.error, 'La ubicación es obligatoria');
    });

    test('el duplicado dentro del archivo no distingue mayúsculas', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile(_csv(['Consultorio 30,Piso 1', 'CONSULTORIO 30,Piso 2'])),
      );

      expect(_errors(preview.errors), {
        3: 'Nombre duplicado. Primera aparición válida en fila 2',
      });
    });

    test('como en el servidor, un nombre que ya existe cuenta como primera aparición', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile(_csv(['Consultorio 7,Piso 9', 'Consultorio 7,Piso 8'])),
      );

      expect(_errors(preview.errors), {
        2: 'El consultorio ya existe en el sistema',
        3: 'Nombre duplicado. Primera aparición válida en fila 2',
      });
    });

    test('"ya existe" no distingue mayúsculas ni espacios', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile(_csv(['  CONSULTORIO 3 ,Piso 5'])),
      );

      expect(_errors(preview.errors), {
        2: 'El consultorio ya existe en el sistema',
      });
    });

    test('guarda el nombre y la ubicación recortados', () async {
      final (db, repository) = _env();

      await repository.confirm(
        clinicCsvFile(_csv(['  Consultorio 20  ,  Piso 3  '])),
      );

      expect(db.clinics.last.name, 'Consultorio 20');
      expect(db.clinics.last.location, 'Piso 3');
    });

    test('acepta punto y coma como separador', () async {
      final (_, repository) = _env();

      final preview = await repository.preview(
        clinicCsvFile('nombre;ubicacion\nConsultorio 20;Piso 3\n'),
      );

      expect(preview.valid, 1);
    });
  });

  group('el archivo no sirve', () {
    test('con un encabezado equivocado lanza CsvFormatException', () async {
      final (_, repository) = _env();

      await expectLater(
        repository.preview(clinicCsvFile('nombre,otra\nA,B\n')),
        throwsA(
          isA<CsvFormatException>().having(
            (e) => e.message,
            'message',
            'El CSV debe tener exactamente las columnas: nombre,ubicacion',
          ),
        ),
      );
      await expectLater(
        repository.confirm(clinicCsvFile('nombre,otra\nA,B\n')),
        throwsA(isA<CsvFormatException>()),
      );
    });

    test('con más de 1000 filas lanza el error de filas', () async {
      final (db, repository) = _env();
      final rows = [
        for (var i = 0; i < 1001; i++) 'Consultorio ${100 + i},Piso 1',
      ];

      await expectLater(
        repository.confirm(clinicCsvFile(_csv(rows))),
        throwsA(
          isA<CsvFormatException>().having(
            (e) => e.message,
            'message',
            'El archivo supera el máximo de 1000 filas de datos',
          ),
        ),
      );
      expect(db.clinics.length, 3);
    });
  });
}
