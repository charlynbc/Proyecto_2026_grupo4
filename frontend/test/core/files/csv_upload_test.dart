import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_upload.dart';
import 'package:agenda_medica/core/files/picked_csv_file.dart';
import 'package:flutter_test/flutter_test.dart';

PickedCsvFile _fileOfSize(int size) =>
    PickedCsvFile(name: 'x.csv', bytes: Uint8List(size));

void main() {
  test('buildImportFormData arma el multipart con el campo archivo', () async {
    final csv = 'nombre,requiere_pase\nCardiologia,si\n';
    final file = PickedCsvFile(
      name: 'especialidades.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );

    final formData = buildImportFormData(file);
    final chunks = await formData.finalize().toList();
    final body = utf8.decode(chunks.expand((c) => c).toList());
    final lower = body.toLowerCase();

    expect(formData.files, hasLength(1));
    expect(formData.fields, isEmpty);
    expect(body, contains('name="archivo"'));
    expect(body, contains('filename="especialidades.csv"'));
    // Dio escribe los nombres de los encabezados en minúscula.
    expect(lower, contains('content-type: text/csv'));
    expect(body, contains(csv));
  });

  group('límite de 1 MB', () {
    test('kMaxCsvBytes es 1 MB', () {
      expect(kMaxCsvBytes, 1048576);
    });

    test('1048576 bytes no excede', () {
      expect(csvExceedsLimit(_fileOfSize(1048576)), isFalse);
    });

    test('1048577 bytes excede', () {
      expect(csvExceedsLimit(_fileOfSize(1048577)), isTrue);
    });

    test('0 bytes no excede', () {
      expect(csvExceedsLimit(_fileOfSize(0)), isFalse);
    });
  });
}
