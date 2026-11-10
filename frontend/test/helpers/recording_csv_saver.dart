import 'dart:async';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_file_saver.dart';

/// Un guardador de CSV falso: anota lo que se le pide guardar.
class RecordingCsvSaver implements CsvFileSaver {
  /// Cada llamada a [save], en orden.
  final List<({String name, Uint8List bytes})> saved = [];

  /// Si no es nulo, [save] lo lanza.
  Object? error;

  /// Si no es nulo, [save] espera a que se complete.
  Completer<void>? gate;

  @override
  Future<void> save(String fileName, Uint8List bytes) async {
    saved.add((name: fileName, bytes: bytes));
    await gate?.future;
    if (error != null) throw error!;
  }
}
