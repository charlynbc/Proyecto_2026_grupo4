import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/picked_csv_file.dart';

/// El encabezado exacto de la carga masiva de especialidades.
const String kSpecialtyImportHeader = 'nombre,requiere_pase';

/// El archivo `especialidades-prueba.csv` de la tarjeta RF-30. Contra los
/// datos sembrados (Medicina General, Cardiología y Dermatología) da, a
/// mano: total 7, 3 válidas (filas 2, 5 y 8) y 4 con error (filas 3, 4, 6
/// y 7).
const String kSpecialtyImportCsv =
    '$kSpecialtyImportHeader\n'
    'Neurología,si\n'
    'Traumatología,tal vez\n'
    'Cardiología,si\n'
    'Pediatría,no\n'
    'Pediatría,no\n'
    ',si\n'
    'Oftalmología,no\n';

/// Un [PickedCsvFile] con [text] codificado en UTF-8.
PickedCsvFile specialtyCsvFile(
  String text, {
  String name = 'especialidades-prueba.csv',
}) => PickedCsvFile(name: name, bytes: Uint8List.fromList(utf8.encode(text)));

/// El archivo de prueba completo.
PickedCsvFile specialtyImportFile() => specialtyCsvFile(kSpecialtyImportCsv);
