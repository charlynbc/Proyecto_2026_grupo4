import 'package:dio/dio.dart';

import 'picked_csv_file.dart';

/// Tamaño máximo del archivo: 1 MB.
const int kMaxCsvBytes = 1048576;

/// `true` si [file] supera el máximo que acepta el servidor.
bool csvExceedsLimit(PickedCsvFile file) => throw UnimplementedError();

/// El cuerpo multipart de una carga masiva: el archivo en el campo
/// `archivo`.
FormData buildImportFormData(PickedCsvFile file) => throw UnimplementedError();
