import 'dart:ui' show Color;

/// Colores de un tramo o de un rango: el relleno, el color del número que va
/// encima y un borde fino.
class StatsShade {
  const StatsShade({required this.fill, required this.text, this.border});

  final Color fill;
  final Color text;
  final Color? border;
}

/// Pases: tres tramos que se distinguen por luminosidad (oscuro, medio y
/// claro), así que también se separan en escala de grises. Cada texto tiene
/// un contraste mínimo de 4,5:1 con su fondo.
const referralUsedShade = StatsShade(
  fill: Color(0xFF1F3A66),
  text: Color(0xFFFFFFFF),
  border: Color(0xFF14264A),
);
const referralAvailableShade = StatsShade(
  fill: Color(0xFF7FA6DE),
  text: Color(0xFF0B1B33),
  border: Color(0xFF4A6FA5),
);
const referralExpiredShade = StatsShade(
  fill: Color(0xFFE3ECF8),
  text: Color(0xFF1B2A41),
  border: Color(0xFF8FA3BF),
);

/// Franjas: las celdas en cero van en gris neutro.
const timeSlotZeroShade = StatsShade(
  fill: Color(0xFFE8E8E8),
  text: Color(0xFF212121),
);

/// Franjas: escala de un solo recorrido, de amarillo claro a rojo oscuro, de
/// menor a mayor cantidad. El texto es blanco sobre los dos rangos oscuros.
const timeSlotScale = <StatsShade>[
  StatsShade(fill: Color(0xFFFFF3B0), text: Color(0xFF212121)),
  StatsShade(fill: Color(0xFFFFD166), text: Color(0xFF212121)),
  StatsShade(fill: Color(0xFFF79D3C), text: Color(0xFF212121)),
  StatsShade(fill: Color(0xFFCC3A21), text: Color(0xFFFFFFFF)),
  StatsShade(fill: Color(0xFF8B1A1A), text: Color(0xFFFFFFFF)),
];
