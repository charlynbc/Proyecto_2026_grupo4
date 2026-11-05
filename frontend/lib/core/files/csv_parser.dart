import 'dart:typed_data';

import '../network/api_exception.dart';

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

CsvTable parseCsv(
  Uint8List bytes, {
  required List<String> expectedHeader,
  int maxRows = 1000,
}) => throw UnimplementedError();
