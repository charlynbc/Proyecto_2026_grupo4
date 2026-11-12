import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _header = ['nombre', 'requiere_pase'];
const _header3 = ['ci', 'nombre', 'correo'];

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

CsvTable _parse(String text) => parseCsv(_bytes(text), expectedHeader: _header);

Matcher _formatError(String message) => throwsA(
  isA<CsvFormatException>().having((e) => e.message, 'message', message),
);

void main() {
  group('lectura', () {
    test('encabezado y filas', () {
      final table = _parse('nombre,requiere_pase\nA,si\nB,no\n');

      expect(table.header, ['nombre', 'requiere_pase']);
      expect(table.rows, [
        ['A', 'si'],
        ['B', 'no'],
      ]);
    });

    test('guarda el encabezado del archivo en su orden', () {
      final table = _parse('requiere_pase,nombre\nsi,A\nno\n');

      expect(table.header, ['nombre', 'requiere_pase']);
      expect(table.fileHeader, ['requiere_pase', 'nombre']);
      // La completa se reordena; la corta queda cruda, en el orden del archivo.
      expect(table.rows, [
        ['A', 'si'],
        ['no'],
      ]);
    });

    test('BOM inicial, punto y coma y fin de línea CRLF', () {
      final table = _parse('﻿nombre;requiere_pase\r\nA;si\r\n');

      expect(table.header, ['nombre', 'requiere_pase']);
      expect(table.rows, [
        ['A', 'si'],
      ]);
    });

    test('un campo entre comillas puede llevar el separador', () {
      final table = _parse('nombre,requiere_pase\n"Gineco, obstetricia",si\n');

      expect(table.rows, [
        ['Gineco, obstetricia', 'si'],
      ]);
    });

    test('comillas dobles escapadas', () {
      final table = _parse('nombre,requiere_pase\n"Dice ""hola""",no\n');

      expect(table.rows, [
        ['Dice "hola"', 'no'],
      ]);
    });

    test('un campo entre comillas puede llevar saltos de línea', () {
      final table = _parse('nombre,requiere_pase\n"Uno\ndos",si\n');

      expect(table.rows, [
        ['Uno\ndos', 'si'],
      ]);
    });

    test('el encabezado se acepta con espacios alrededor', () {
      final table = _parse(' nombre , requiere_pase \nA,si\n');

      expect(table.header, ['nombre', 'requiere_pase']);
      expect(table.rows, [
        ['A', 'si'],
      ]);
    });

    test('un encabezado en otro orden reordena las filas', () {
      final table = parseCsv(
        _bytes('nombre,ci,correo\nAna,1,a@x\nBeto,2,b@x\n'),
        expectedHeader: _header3,
      );

      expect(table.header, ['ci', 'nombre', 'correo']);
      expect(table.rows, [
        ['1', 'Ana', 'a@x'],
        ['2', 'Beto', 'b@x'],
      ]);
    });

    test('con dos columnas en otro orden también reordena', () {
      final table = _parse('requiere_pase,nombre\nsi,A\nno,B\n');

      expect(table.rows, [
        ['A', 'si'],
        ['B', 'no'],
      ]);
    });

    test('una línea en blanco en el medio se saltea', () {
      final table = _parse('nombre,requiere_pase\nA,si\n\nB,no\n');

      expect(table.rows, [
        ['A', 'si'],
        ['B', 'no'],
      ]);
    });

    test('las líneas en blanco al final y las seguidas se saltean', () {
      final table = _parse('nombre,requiere_pase\nA,si\n\n\nB,no\n\n\n');

      expect(table.rows, [
        ['A', 'si'],
        ['B', 'no'],
      ]);
    });

    test('una línea en blanco antes del encabezado se saltea', () {
      final table = _parse('\n\nnombre,requiere_pase\nA,si\n');

      expect(table.rows, [
        ['A', 'si'],
      ]);
    });

    test('una línea con solo espacios es una fila', () {
      final table = _parse('nombre,requiere_pase\n   \nA,si\n');

      expect(table.rows, [
        ['   '],
        ['A', 'si'],
      ]);
    });

    test('las líneas en blanco no cuentan para el máximo de filas', () {
      final text = 'nombre,requiere_pase\n${'A,si\n\n' * 1000}';

      expect(_parse(text).rows, hasLength(1000));
    });

    test('solo el encabezado da cero filas', () {
      expect(_parse('nombre,requiere_pase\n').rows, isEmpty);
    });

    test('el separador es punto y coma si el encabezado tiene alguno', () {
      final table = parseCsv(
        _bytes('nombre;"requiere,pase"\nA;si\n'),
        expectedHeader: const ['nombre', 'requiere,pase'],
      );

      expect(table.rows, [
        ['A', 'si'],
      ]);
    });

    test('una fila con otra cantidad de celdas se devuelve cruda', () {
      final table = _parse('requiere_pase,nombre\nsi,A\nsolo\nx,y,z\n');

      expect(table.rows, [
        ['A', 'si'],
        ['solo'],
        ['x', 'y', 'z'],
      ]);
    });

    test('las celdas no se recortan', () {
      final table = _parse('nombre,requiere_pase\n A , si \n');

      expect(table.rows, [
        [' A ', ' si '],
      ]);
    });

    test('1000 filas de datos pasan', () {
      final text = 'nombre,requiere_pase\n${'A,si\n' * 1000}';

      expect(_parse(text).rows, hasLength(1000));
    });
  });

  group('errores', () {
    const columnsError =
        'El CSV debe tener exactamente las columnas: nombre, requiere_pase';
    const genericError =
        'El archivo CSV está vacío o tiene un formato inválido';

    test('encabezado equivocado', () {
      expect(() => _parse('nombre,otra\nA,si\n'), _formatError(columnsError));
    });

    test('encabezado con una columna de más', () {
      expect(
        () => _parse('nombre,requiere_pase,extra\nA,si,x\n'),
        _formatError(columnsError),
      );
    });

    test('encabezado con una columna de menos', () {
      expect(() => _parse('nombre\nA\n'), _formatError(columnsError));
    });

    test('el encabezado distingue mayúsculas', () {
      expect(
        () => _parse('NOMBRE,requiere_pase\nA,si\n'),
        _formatError(columnsError),
      );
    });

    test('el mensaje de columnas separa con coma y espacio', () {
      expect(
        () => parseCsv(_bytes('x,y,z\n1,2,3\n'), expectedHeader: _header3),
        _formatError(
          'El CSV debe tener exactamente las columnas: ci, nombre, correo',
        ),
      );
    });

    test('columna repetida', () {
      expect(() => _parse('nombre,nombre\nA,B\n'), _formatError(genericError));
    });

    test('columna repetida con una de más va por el mensaje genérico', () {
      expect(
        () => _parse('nombre,nombre,requiere_pase\nA,B,si\n'),
        _formatError(genericError),
      );
    });

    test('columna con nombre vacío', () {
      expect(
        () => parseCsv(_bytes('ci,,correo\n1,2,3\n'), expectedHeader: _header3),
        _formatError(genericError),
      );
    });

    test('UTF-8 inválido', () {
      expect(
        () => parseCsv(
          Uint8List.fromList([0xFF, 0xFE, 0x41]),
          expectedHeader: _header,
        ),
        _formatError('El archivo no es texto UTF-8 válido'),
      );
    });

    test('archivo de 0 bytes', () {
      expect(
        () => parseCsv(Uint8List(0), expectedHeader: _header),
        _formatError('Debe seleccionar un archivo CSV no vacío'),
      );
    });

    test('solo espacios', () {
      expect(() => _parse('  \n \n'), _formatError(genericError));
    });

    test('1001 filas de datos', () {
      final text = 'nombre,requiere_pase\n${'A,si\n' * 1001}';

      expect(
        () => _parse(text),
        _formatError('El archivo supera el máximo de 1000 filas de datos'),
      );
    });

    test('más de 1 MB', () {
      expect(
        () => parseCsv(Uint8List(1048577), expectedHeader: _header),
        _formatError('El archivo supera el tamaño máximo permitido (1 MB)'),
      );
    });
  });
}
