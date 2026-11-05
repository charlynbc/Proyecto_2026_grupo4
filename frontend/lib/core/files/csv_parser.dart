import 'dart:convert';
import 'dart:typed_data';

import '../network/api_exception.dart';
import 'csv_upload.dart';

/// El archivo no tiene el formato esperado. El mensaje se puede mostrar tal
/// cual.
class CsvFormatException extends ApiException {
  const CsvFormatException(super.message);
}

/// El contenido de un CSV: el encabezado y las filas de datos. La fila de
/// datos `i` es la número `i + 2` del archivo (la 1 es el encabezado).
class CsvTable {
  const CsvTable({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;
}

/// Lee un CSV con las mismas reglas que el servidor: UTF-8 (con o sin BOM),
/// separador coma o punto y coma según la línea de encabezado, campos entre
/// comillas, y las columnas exactamente [expectedHeader] (sin importar
/// mayúsculas ni espacios sobrantes en los nombres).
///
/// Sirve para mostrar una vista previa o avisar antes de subir: la regla
/// definitiva es del servidor. Las celdas no se recortan.
CsvTable parseCsv(
  Uint8List bytes, {
  required List<String> expectedHeader,
  int maxRows = 1000,
}) {
  if (bytes.length > kMaxCsvBytes) {
    throw const CsvFormatException(
      'El archivo supera el tamaño máximo permitido (1 MB)',
    );
  }

  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const CsvFormatException('El archivo no es texto UTF-8 válido');
  }
  if (text.startsWith('﻿')) text = text.substring(1);

  if (text.trim().isEmpty) {
    throw const CsvFormatException(
      'El archivo CSV está vacío o tiene un formato inválido',
    );
  }

  final records = _readRecords(text, _detectSeparator(text));

  final header = records.first;
  final matches =
      header.length == expectedHeader.length &&
      [
        for (var i = 0; i < header.length; i++)
          header[i].trim().toLowerCase() ==
              expectedHeader[i].trim().toLowerCase(),
      ].every((same) => same);
  if (!matches) {
    throw CsvFormatException(
      'El CSV debe tener exactamente las columnas: ${expectedHeader.join(',')}',
    );
  }

  final rows = records.sublist(1);
  if (rows.length > maxRows) {
    throw CsvFormatException(
      'El archivo supera el máximo de $maxRows filas de datos',
    );
  }
  return CsvTable(header: header, rows: rows);
}

/// `;` si la línea de encabezado tiene más punto y coma que comas; si no `,`.
String _detectSeparator(String text) {
  final end = text.indexOf(RegExp(r'[\r\n]'));
  final line = end < 0 ? text : text.substring(0, end);
  final semicolons = ';'.allMatches(line).length;
  final commas = ','.allMatches(line).length;
  return semicolons > commas ? ';' : ',';
}

/// Parte [text] en registros y campos. Un campo que arranca con comilla
/// termina en la próxima comilla que no esté duplicada y puede llevar el
/// separador y saltos de línea. El salto de línea final no genera registro;
/// una línea en blanco en el medio es un registro con una celda vacía.
List<List<String>> _readRecords(String text, String separator) {
  final records = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var fieldWasQuoted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
    fieldWasQuoted = false;
  }

  void endRecord() {
    final blank = row.isEmpty && field.isEmpty && !fieldWasQuoted;
    if (blank) {
      records.add(['']);
    } else {
      endField();
      records.add(row);
    }
    row = <String>[];
  }

  var i = 0;
  while (i < text.length) {
    final char = text[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
      }
    } else if (char == '"' && field.isEmpty && !fieldWasQuoted) {
      inQuotes = true;
      fieldWasQuoted = true;
    } else if (char == separator) {
      endField();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRecord();
    } else {
      field.write(char);
    }
    i++;
  }
  // Lo que queda sin salto de línea final es el último registro.
  if (row.isNotEmpty || field.isNotEmpty || fieldWasQuoted) endRecord();
  return records;
}
