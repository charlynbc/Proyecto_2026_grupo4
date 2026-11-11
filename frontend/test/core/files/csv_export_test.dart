import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_export.dart';
import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/specialty_errors_csv.dart';

Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));

/// Una tabla de una sola columna `valor` con [cell] como única fila (la 2),
/// y el CSV de ese error.
Uint8List _single(String cell) => buildErrorRowsCsv(
  original: CsvTable(
    header: const ['valor'],
    rows: [
      [cell],
    ],
  ),
  errorsByRow: const {2: 'e'},
);

/// Lo que se espera para una tabla de una columna con la celda ya escrita
/// como debe salir (con sus comillas).
String _expectedSingle(String quotedCell) =>
    '﻿"valor";"error"\r\n$quotedCell;"e"\r\n';

void main() {
  group('el archivo completo', () {
    test('las filas con error de especialidades, en orden y en bytes', () {
      final bytes = buildErrorRowsCsv(
        original: kSpecialtyOriginalTable,
        errorsByRow: kSpecialtyErrorsByRow,
      );

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(bytes, _utf8(kSpecialtyErrorsCsvText));
    });

    test('sin errores queda solo el encabezado', () {
      final bytes = buildErrorRowsCsv(
        original: kSpecialtyOriginalTable,
        errorsByRow: const {},
      );

      expect(bytes, _utf8('﻿"nombre";"requiere_pase";"error"\r\n'));
    });
  });

  group('comillas y fórmulas', () {
    test('la comilla interna se duplica', () {
      expect(_single('Dice "hola"'), _utf8(_expectedSingle('"Dice ""hola"""')));
    });

    test(
      'el separador y los saltos de línea quedan dentro de las comillas',
      () {
        expect(_single('a;b\nc'), _utf8(_expectedSingle('"a;b\nc"')));
      },
    );

    for (final (input, output) in [
      ('=CMD()', "\"'=CMD()\""),
      ('@x', "\"'@x\""),
      ('+cmd()', "\"'+cmd()\""),
      ('-cmd()', "\"'-cmd()\""),
      ('\tx', "\"'\tx\""),
      ('\rx', "\"'\rx\""),
    ]) {
      test('${jsonEncode(input)} lleva apóstrofo', () {
        expect(_single(input), _utf8(_expectedSingle(output)));
      });
    }

    for (final value in ['+59899123456', '-12', '(02) 123-45', 'a=b', "'=x"]) {
      test('$value queda igual', () {
        expect(_single(value), _utf8(_expectedSingle('"$value"')));
      });
    }

    test('el apóstrofo va dentro de las comillas y la comilla se duplica', () {
      expect(_single('=A("x")'), _utf8(_expectedSingle('"\'=A(""x"")"')));
    });
  });

  group('casos del borde', () {
    const header = ['a', 'b', 'c'];

    test('un número que no existe se omite sin lanzar', () {
      final bytes = buildErrorRowsCsv(
        original: const CsvTable(
          header: header,
          rows: [
            ['1', '2', '3'],
            ['4', '5', '6'],
          ],
        ),
        errorsByRow: const {99: 'x', 5: 'y', 1: 'z', 0: 'w', -3: 'v', 3: 'ok'},
      );

      expect(bytes, _utf8('﻿"a";"b";"c";"error"\r\n"4";"5";"6";"ok"\r\n'));
    });

    test('una fila corta se completa y error queda en la última columna', () {
      final bytes = buildErrorRowsCsv(
        original: const CsvTable(
          header: header,
          rows: [
            ['solo'],
          ],
        ),
        errorsByRow: const {2: 'faltan celdas'},
      );

      expect(
        bytes,
        _utf8('﻿"a";"b";"c";"error"\r\n"solo";"";"";"faltan celdas"\r\n'),
      );
    });

    test('una fila con celdas de más se copia entera', () {
      final bytes = buildErrorRowsCsv(
        original: const CsvTable(
          header: header,
          rows: [
            ['1', '2', '3', '4'],
          ],
        ),
        errorsByRow: const {2: 'sobran'},
      );

      expect(
        bytes,
        _utf8('﻿"a";"b";"c";"error"\r\n"1";"2";"3";"4";"sobran"\r\n'),
      );
    });

    test('tildes y eñes salen en UTF-8', () {
      final bytes = _single('Año');

      // A, ñ (C3 B1), o
      expect(bytes, containsAllInOrder([0x41, 0xC3, 0xB1, 0x6F]));
      expect(bytes, _utf8(_expectedSingle('"Año"')));
    });
  });

  group('el archivo subido con las columnas en otro orden', () {
    const expected = ['nombre', 'requiere_pase'];

    /// El CSV de rechazadas del archivo [text] (lo que sube la persona), con
    /// el motivo dado a cada fila de datos desde la 2.
    Uint8List download(String text, Map<int, String> errors) {
      final table = parseCsv(_utf8(text), expectedHeader: expected);
      return buildErrorRowsCsv(original: table, errorsByRow: errors);
    }

    test('fila completa: cada celda queda bajo su columna', () {
      final bytes = download('requiere_pase,nombre\nsi,Neurología\n', const {
        2: 'Motivo',
      });

      expect(
        bytes,
        _utf8(
          '\uFEFF"nombre";"requiere_pase";"error"\r\n'
          '"Neurología";"si";"Motivo"\r\n',
        ),
      );
    });

    test('fila corta: "si" queda bajo requiere_pase y nombre queda vacío', () {
      final bytes = download('requiere_pase,nombre\nsi\n', const {2: 'Motivo'});

      expect(
        bytes,
        _utf8(
          '\uFEFF"nombre";"requiere_pase";"error"\r\n'
          '"";"si";"Motivo"\r\n',
        ),
      );
    });

    test('fila corta con las columnas en el orden esperado', () {
      final bytes = download('nombre,requiere_pase\nNeurología\n', const {
        2: 'Motivo',
      });

      expect(
        bytes,
        _utf8(
          '\uFEFF"nombre";"requiere_pase";"error"\r\n'
          '"Neurología";"";"Motivo"\r\n',
        ),
      );
    });

    test('filas con distinta cantidad de celdas en el mismo archivo', () {
      final bytes = download(
        'requiere_pase,nombre\n'
        'si,Ana\n'
        'no\n'
        'si,Luis,sobra\n',
        const {2: 'Uno', 3: 'Dos', 4: 'Tres'},
      );

      // La celda de más se copia después de las columnas conocidas.
      expect(
        bytes,
        _utf8(
          '\uFEFF"nombre";"requiere_pase";"error"\r\n'
          '"Ana";"si";"Uno"\r\n'
          '"";"no";"Dos"\r\n'
          '"Luis";"si";"sobra";"Tres"\r\n',
        ),
      );
    });

    test(
      'con punto y coma y cuatro columnas, la corta no corre sus celdas',
      () {
        final table = parseCsv(
          _utf8('c;a;d;b\n3;1\n'),
          expectedHeader: const ['a', 'b', 'c', 'd'],
        );

        final bytes = buildErrorRowsCsv(
          original: table,
          errorsByRow: const {2: 'm'},
        );

        // 3 es de c y 1 es de a: las otras quedan vacías.
        expect(
          bytes,
          _utf8(
            '\uFEFF"a";"b";"c";"d";"error"\r\n'
            '"1";"";"3";"";"m"\r\n',
          ),
        );
      },
    );
  });

  test('ida y vuelta: parseCsv devuelve las mismas celdas y motivos', () {
    final bytes = buildErrorRowsCsv(
      original: const CsvTable(
        header: ['nombre', 'requiere_pase'],
        rows: [
          ['Válida', 'si'],
          ['Dice "hola"; y\nchau', 'tal vez'],
          ['', 'si'],
        ],
      ),
      errorsByRow: const {3: 'Motivo; con "comillas"', 4: 'Otro motivo'},
    );

    final table = parseCsv(
      bytes,
      expectedHeader: const ['nombre', 'requiere_pase', 'error'],
    );

    expect(table.header, ['nombre', 'requiere_pase', 'error']);
    expect(table.rows, [
      ['Dice "hola"; y\nchau', 'tal vez', 'Motivo; con "comillas"'],
      ['', 'si', 'Otro motivo'],
    ]);
  });
}
