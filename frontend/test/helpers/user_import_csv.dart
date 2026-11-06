import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/picked_csv_file.dart';

/// El encabezado exacto de la carga masiva de usuarios.
const String kUserImportHeader =
    'ci,nombre,apellido,fecha_nacimiento,correo,telefono_1,telefono_2,'
    'direccion,rol,especialidades';

/// El archivo `usuarios-prueba.csv` de la tarjeta RF-32. Contra los datos
/// sembrados da, a mano: total 11, 3 válidas (filas 2, 3 y 6) y 8 con error
/// (filas 4, 5, 7, 8, 9, 10, 11 y 12).
const String kUserImportCsv =
    '$kUserImportHeader\n'
    '30000010,Julia,Ferrari,1992-03-15,julia.ferrari@example.org,099111222,,Av. Italia 1234,SOCIO,\n'
    '30000026,Marcos,Gil,1980-07-02,marcos.gil@example.org,099333444,,,medico,Cardiología|Dermatología\n'
    '30000033,Sara,Lima,1991-04-04,sara.lima@example.org,099121212,,,SOCIO,\n'
    '12345672,Ana,Rodríguez,1985-01-04,ana.rodriguez@example.org,099555666,,,SOCIO,\n'
    '12345672,Ana,Rodríguez,1985-01-04,ana.rodriguez@example.org,099555666,,,FUNCIONARIO,\n'
    '23456783,Bruno,Pereira,1990-12-21,bruno.pereira@example.org,099444555,,,FUNCIONARIO,\n'
    '34567894,Carla,Gomez,1978-11-11,carla.gomez@example.org,099666777,,,MEDICO,Cardiología\n'
    '30000048,Luis,Perez,1975-05-05,luis.perez@example.org,099777888,,,MEDICO,Oncología\n'
    '30000054,Rita,Mora,1999-01-30,rita.mora@example,099999000,,,SOCIO,\n'
    '30000010,Julia,Ferrari,1992-03-15,julia.ferrari@example.org,099111222,,Av. Italia 1234,SOCIO,\n'
    '30000060,Pablo,Rios,1985-02-30,pablo.rios@example.org,099808080,,,SOCIO,\n';

/// Un [PickedCsvFile] con [text] codificado en UTF-8.
PickedCsvFile csvFile(String text, {String name = 'usuarios-prueba.csv'}) =>
    PickedCsvFile(name: name, bytes: Uint8List.fromList(utf8.encode(text)));

/// El archivo de prueba completo.
PickedCsvFile userImportFile() => csvFile(kUserImportCsv);
