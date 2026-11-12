import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Guarda un CSV que armó la app (por ejemplo las filas rechazadas de una
/// carga masiva).
abstract class CsvFileSaver {
  /// Guarda [bytes] con el nombre [fileName]. Si la persona cancela no hace
  /// nada. Si no se puede guardar, lanza.
  Future<void> save(String fileName, Uint8List bytes);
}

/// El guardador real, sobre `file_picker`. No se prueba con tests: abre el
/// diálogo del sistema o baja el archivo por el navegador. Todo lo demás
/// recibe un [CsvFileSaver] y se prueba con uno falso.
///
/// En web `saveFile` baja el archivo directo y siempre devuelve `null`, así
/// que no hay forma de distinguir guardar de cancelar: por eso el resultado
/// no se usa.
class FilePickerCsvSaver implements CsvFileSaver {
  const FilePickerCsvSaver();

  @override
  Future<void> save(String fileName, Uint8List bytes) async {
    await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/csv',
    );
  }
}

/// El guardador de CSV. Los tests lo sobrescriben con uno falso.
final csvFileSaverProvider = Provider<CsvFileSaver>(
  (ref) => const FilePickerCsvSaver(),
);
