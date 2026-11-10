import 'package:agenda_medica/core/files/csv_parser.dart';

/// Las filas de datos (números 2 a 8) de `especialidades-prueba.csv`, escritas
/// a mano.
const CsvTable kSpecialtyOriginalTable = CsvTable(
  header: ['nombre', 'requiere_pase'],
  rows: [
    ['Neurología', 'si'],
    ['Traumatología', 'tal vez'],
    ['Cardiología', 'si'],
    ['Pediatría', 'no'],
    ['Pediatría', 'no'],
    ['', 'si'],
    ['Oftalmología', 'no'],
  ],
);

/// Los motivos que da la previsualización falsa, escritos a mano. Fuera de
/// orden a propósito.
const Map<int, String> kSpecialtyErrorsByRow = {
  6: 'Nombre duplicado. Primera aparición válida en fila 5',
  3: 'requiere_pase debe ser si o no',
  7: 'El nombre es obligatorio',
  4: 'La especialidad ya existe en el sistema',
};

/// El archivo de filas rechazadas que se espera para las dos constantes de
/// arriba: BOM, punto y coma, todo entre comillas, fin de línea CRLF.
const String kSpecialtyErrorsCsvText =
    '﻿"nombre";"requiere_pase";"error"\r\n'
    '"Traumatología";"tal vez";"requiere_pase debe ser si o no"\r\n'
    '"Cardiología";"si";"La especialidad ya existe en el sistema"\r\n'
    '"Pediatría";"no";"Nombre duplicado. Primera aparición válida en fila 5"\r\n'
    '"";"si";"El nombre es obligatorio"\r\n';
