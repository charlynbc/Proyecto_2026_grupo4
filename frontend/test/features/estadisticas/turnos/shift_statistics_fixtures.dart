/// La respuesta de ejemplo del contrato de `GET /api/estadisticas/turnos`,
/// con `fechasActivas` y `utilizacion` según la descripción del contrato.
Map<String, dynamic> contractBody() => {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'items': <Map<String, dynamic>>[
    {
      'turnoSemanalId': 120,
      'medico': {'id': 17, 'nombre': 'Marta', 'apellido': 'Rodríguez'},
      'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
      'consultorio': {
        'id': 5,
        'nombre': 'Consultorio 5',
        'ubicacion': 'Piso 2, ala norte',
      },
      'diaSemana': 2,
      'fechasActivas': 4,
      'numerosOfrecidos': 12,
      'numerosOcupados': 9,
      'porcentajeUtilizacion': 75.0,
      'utilizacion': '75 %',
    },
    {
      'turnoSemanalId': 121,
      'medico': {'id': 21, 'nombre': 'Jorge', 'apellido': 'Pereira'},
      'especialidad': {
        'id': 1,
        'nombre': 'Medicina General',
        'requierePase': false,
      },
      'consultorio': {
        'id': 6,
        'nombre': 'Consultorio 6',
        'ubicacion': 'Piso 2, ala sur',
      },
      'diaSemana': 4,
      'fechasActivas': 0,
      'numerosOfrecidos': 0,
      'numerosOcupados': 0,
      'porcentajeUtilizacion': null,
      'utilizacion': 'Sin datos',
    },
  ],
};

/// El primer ítem del contrato, para tocarle un campo en un test.
Map<String, dynamic> firstItem(Map<String, dynamic> body) =>
    (body['items'] as List<Map<String, dynamic>>)[0];
