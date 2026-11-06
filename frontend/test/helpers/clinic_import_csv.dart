import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/picked_csv_file.dart';

/// El encabezado exacto de la carga masiva de consultorios.
const String kClinicImportHeader = 'nombre,ubicacion';

/// El archivo `consultorios-prueba.csv` de la tarjeta RF-34. Contra los datos
/// sembrados (Consultorio 3, 7 y 12) da, a mano: total 7, 2 válidas (filas 2
/// y 7) y 5 con error (filas 3, 4, 5, 6 y 8).
const String kClinicImportCsv =
    '$kClinicImportHeader\n'
    'Consultorio 20,Piso 3\n'
    'Consultorio 7,Piso 1\n'
    'Consultorio 21,\n'
    'Consultorio 20,Piso 4\n'
    ',Planta baja\n'
    'Consultorio 22,Subsuelo\n'
    'consultorio 12,Piso 2\n';

/// Un [PickedCsvFile] con [text] codificado en UTF-8.
PickedCsvFile clinicCsvFile(
  String text, {
  String name = 'consultorios-prueba.csv',
}) => PickedCsvFile(name: name, bytes: Uint8List.fromList(utf8.encode(text)));

/// El archivo de prueba completo.
PickedCsvFile clinicImportFile() => clinicCsvFile(kClinicImportCsv);
