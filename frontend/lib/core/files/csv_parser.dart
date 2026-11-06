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
/// datos `i` es la número `i + 2` del archivo contando solo las líneas no
/// vacías (la 1 es el encabezado), igual que la numeración del servidor.
class CsvTable {
  const CsvTable({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;
}

/// Lee un CSV con las mismas reglas que el servidor (`CsvArchivo.parsear`):
///
/// - UTF-8 estricto, con o sin BOM inicial.
/// - Separador `;` si la línea de encabezado tiene algún punto y coma; si no,
///   `,`.
/// - Campos entre comillas, que pueden llevar el separador y saltos de línea.
/// - Las líneas en blanco se ignoran y no cuentan como fila ni para el máximo
///   de filas.
/// - Las columnas son exactamente [expectedHeader], en cualquier orden y sin
///   repetir. Se distinguen mayúsculas. Un nombre repetido o vacío da el
///   mensaje genérico del servidor.
/// - Un archivo de 0 bytes, de más de 1 MB o de más de [maxRows] filas se
///   rechaza con el texto del servidor.
///
/// Cada fila se devuelve ya ordenada según [expectedHeader], así quien la
/// lee puede hacerlo por posición. Una fila con otra cantidad de celdas que
/// las esperadas se devuelve cruda, sin reordenar: el servidor la marca con
/// error y quien llama la detecta por su largo. Las celdas no se recortan.
///
/// Diferencias conocidas con el servidor:
///
/// - Espacios alrededor de los nombres del encabezado: acá se aceptan. El
///   servidor valida el encabezado recortado pero después falla al leer las
///   filas, con el mensaje genérico (un error del servidor que no se copia).
/// - Comillas: el servidor rechaza una comilla que cierra seguida de otros
///   caracteres y una comilla sin cerrar; acá se aceptan.
/// - Los espacios que cuentan como "en blanco" para un archivo vacío pueden
///   diferir en algunos caracteres raros entre Java y Dart.
///
/// Sirve para mostrar una vista previa o avisar antes de subir: la regla
/// definitiva es del servidor.
CsvTable parseCsv(
  Uint8List bytes, {
  required List<String> expectedHeader,
  int maxRows = 1000,
}) {
  if (bytes.isEmpty) {
    throw const CsvFormatException('Debe seleccionar un archivo CSV no vacío');
  }
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
  // utf8.decode ya descarta un BOM inicial; esta línea es una defensa
  // explícita (la prueba corre solo en la VM), así que sacarla no rompe tests.
  if (text.startsWith('﻿')) text = text.substring(1);

  const genericMessage =
      'El archivo CSV está vacío o tiene un formato inválido';
  if (text.trim().isEmpty) {
    throw const CsvFormatException(genericMessage);
  }

  final records = _readRecords(text, _detectSeparator(text));

  final header = [for (final name in records.first) name.trim()];
  if (header.any((name) => name.isEmpty) ||
      header.toSet().length != header.length) {
    throw const CsvFormatException(genericMessage);
  }
  if (header.length != expectedHeader.length ||
      !expectedHeader.every(header.contains)) {
    throw CsvFormatException(
      'El CSV debe tener exactamente las columnas: '
      '${expectedHeader.join(', ')}',
    );
  }

  final order = [for (final name in expectedHeader) header.indexOf(name)];
  final rows = [
    for (final record in records.skip(1))
      record.length == order.length
          ? [for (final index in order) record[index]]
          : record,
  ];
  if (rows.length > maxRows) {
    throw CsvFormatException(
      'El archivo supera el máximo de $maxRows filas de datos',
    );
  }
  return CsvTable(header: List.of(expectedHeader), rows: rows);
}

/// `;` si la línea de encabezado tiene algún punto y coma; si no `,`.
String _detectSeparator(String text) {
  final end = text.indexOf(RegExp(r'[\r\n]'));
  final line = end < 0 ? text : text.substring(0, end);
  return line.contains(';') ? ';' : ',';
}

/// Parte [text] en registros y campos. Un campo que arranca con comilla
/// termina en la próxima comilla que no esté duplicada y puede llevar el
/// separador y saltos de línea. Las líneas en blanco no generan registro.
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
    if (!blank) {
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
