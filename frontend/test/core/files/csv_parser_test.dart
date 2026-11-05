import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const _header = ['nombre', 'requiere_pase'];

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

    test('el encabezado se compara sin espacios y sin mayúsculas', () {
      final table = _parse('NOMBRE, Requiere_Pase\nA,si\n');

      expect(table.rows, [
        ['A', 'si'],
      ]);
    });

    test('una línea en blanco en el medio es una fila con una celda vacía', () {
      final table = _parse('nombre,requiere_pase\nA,si\n\nB,no\n');

      expect(table.rows, [
        ['A', 'si'],
        [''],
        ['B', 'no'],
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
    test('encabezado equivocado', () {
      expect(
        () => _parse('nombre,otra\nA,si\n'),
        _formatError(
          'El CSV debe tener exactamente las columnas: nombre,requiere_pase',
        ),
      );
    });

    test('encabezado con una columna de más', () {
      expect(
        () => _parse('nombre,requiere_pase,extra\nA,si,x\n'),
        _formatError(
          'El CSV debe tener exactamente las columnas: nombre,requiere_pase',
        ),
      );
    });

    test('encabezado en otro orden', () {
      expect(
        () => _parse('requiere_pase,nombre\nsi,A\n'),
        _formatError(
          'El CSV debe tener exactamente las columnas: nombre,requiere_pase',
        ),
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

    test('archivo vacío', () {
      expect(
        () => parseCsv(Uint8List(0), expectedHeader: _header),
        _formatError('El archivo CSV está vacío o tiene un formato inválido'),
      );
    });

    test('solo espacios', () {
      expect(
        () => _parse('  \n \n'),
        _formatError('El archivo CSV está vacío o tiene un formato inválido'),
      );
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
