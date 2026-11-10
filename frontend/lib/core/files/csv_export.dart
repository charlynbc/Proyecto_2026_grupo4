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
/// se completa con celdas vacías, así `error` queda siempre en su columna. Una
/// fila con más celdas se copia entera y `error` va al final.
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

  line([...original.header, 'error']);
  for (final number in numbers) {
    final cells = original.rows[number - 2];
    line([
      ...cells,
      for (var i = cells.length; i < original.header.length; i++) '',
      errorsByRow[number]!,
    ]);
  }
  return Uint8List.fromList(utf8.encode(out.toString()));
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
