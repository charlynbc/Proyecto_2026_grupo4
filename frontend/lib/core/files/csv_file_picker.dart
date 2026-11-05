import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'picked_csv_file.dart';

/// Abre el selector de archivos del sistema para elegir un CSV.
abstract class CsvFilePicker {
  /// El archivo elegido, o `null` si la persona canceló.
  Future<PickedCsvFile?> pick();
}

/// El selector real, sobre `file_picker`. No se prueba con tests: abre el
/// diálogo del sistema. Todo lo demás recibe un [CsvFilePicker] y se prueba
/// con uno falso.
class FilePickerCsvPicker implements CsvFilePicker {
  const FilePickerCsvPicker();

  @override
  Future<PickedCsvFile?> pick() async {
    // En file_picker 13 ya no existe `withData`: los bytes se leen del
    // archivo elegido con `readAsBytes`, en web y en Android.
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return null;
    return PickedCsvFile(name: file.name, bytes: await file.readAsBytes());
  }
}

/// El selector de CSV. Los tests lo sobrescriben con uno falso.
final csvFilePickerProvider = Provider<CsvFilePicker>(
  (ref) => const FilePickerCsvPicker(),
);
