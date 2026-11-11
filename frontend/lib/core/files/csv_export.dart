import 'dart:convert';
import 'dart:typed_data';

import 'csv_parser.dart';

/// Arma el CSV de las filas rechazadas de una carga masiva, para corregirlas
/// y volver a subirlas.
///
/// [original] es el archivo que se subió y [errorsByRow] va del número de fila
/// (el del servidor, que cuenta desde 2) al motivo del rechazo. Un número que
/// no está en [original] se omite.
///
/// Formato: UTF-8 con BOM, separador `;`, todas las celdas entre comillas
/// dobles (la comilla interna se duplica), fin de línea `\r\n` también en la
/// última fila, el encabezado original más la columna `error` y solo las filas
/// con error, en orden de número. Una fila con menos celdas que el encabezado
/// se completa con celdas vacías, así `error` queda siempre en su columna. Las
/// celdas de cada fila se ubican por su posición en el encabezado del archivo
/// subido (`CsvTable.fileHeader`), aunque las columnas vinieran en otro orden.
/// Las celdas de más se conservan en columnas `extra_1`, `extra_2`... (tantas
/// como la fila rechazada que más tiene), después de las conocidas y antes de
/// `error`, que va siempre última con el motivo; las filas con menos sobrantes
/// se completan con vacío. Sin celdas de más no hay columnas `extra_N`. Para
/// volver a subir el archivo hay que borrar `error` y las `extra_N`: el
/// servidor exige exactamente las columnas de la carga.
///
/// Si una celda empieza con `=`, `@`, tabulación o retorno de carro (o con `+`
/// o `-` sin ser un número o un teléfono) se le antepone un apóstrofo para que
/// la planilla no la tome por una fórmula.
Uint8List buildErrorRowsCsv({
  required CsvTable original,
  required Map<int, String> errorsByRow,
}) {
  final numbers = [
    for (final number in errorsByRow.keys)
      if (number >= 2 && number - 2 < original.rows.length) number,
  ]..sort();

  final out = StringBuffer('﻿');
  void line(List<String> cells) {
    out
      ..writeAll(cells.map(_quote), ';')
      ..write('\r\n');
  }

  final rows = [
    for (final number in numbers)
      _underHeader(original, original.rows[number - 2]),
  ];
  // Las celdas de más van bajo extra_1, extra_2... (tantas como la fila que
  // más tiene) y `error` queda siempre última.
  final extraColumns = rows.fold<int>(
    0,
    (most, row) => row.extra.length > most ? row.extra.length : most,
  );
  line([
    ...original.header,
    for (var i = 1; i <= extraColumns; i++) 'extra_$i',
    'error',
  ]);
  for (var i = 0; i < rows.length; i++) {
    line([
      ...rows[i].known,
      ...rows[i].extra,
      for (var j = rows[i].extra.length; j < extraColumns; j++) '',
      errorsByRow[numbers[i]]!,
    ]);
  }
  return Uint8List.fromList(utf8.encode(out.toString()));
}

/// Las celdas de una fila bajo la columna que les corresponde. Una fila con la
/// cantidad esperada de celdas ya viene en el orden de `header`. Una corta o
/// larga viene cruda, en el orden del archivo: cada celda se ubica por su
/// posición en el encabezado del archivo, las que faltan quedan vacías y las
/// de más se devuelven aparte, en su orden.
({List<String> known, List<String> extra}) _underHeader(
  CsvTable table,
  List<String> cells,
) {
  final fileHeader = table.fileHeader;
  final columns = table.header.length;
  if (fileHeader == null || cells.length == columns) {
    return (
      known: [
        ...cells.take(columns),
        for (var i = cells.length; i < columns; i++) '',
      ],
      extra: cells.skip(columns).toList(),
    );
  }
  final placed = List<String>.filled(columns, '');
  final extra = <String>[];
  for (var i = 0; i < cells.length; i++) {
    final column = i < fileHeader.length
        ? table.header.indexOf(fileHeader[i])
        : -1;
    if (column < 0) {
      extra.add(cells[i]);
    } else {
      placed[column] = cells[i];
    }
  }
  return (known: placed, extra: extra);
}

String _quote(String value) {
  final safe = _startsLikeFormula(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

/// Lo que sigue a un `+` o `-` en un número o un teléfono: dígitos, espacios,
/// paréntesis y guiones.
final RegExp _numberLike = RegExp(r'^[0-9 ()\-]*$');

bool _startsLikeFormula(String value) {
  if (value.isEmpty) return false;
  switch (value[0]) {
    case '=' || '@' || '\t' || '\r':
      return true;
    case '+' || '-':
      return !_numberLike.hasMatch(value.substring(1));
    default:
      return false;
  }
}
