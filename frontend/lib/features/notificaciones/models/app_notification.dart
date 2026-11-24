/// Un instante con zona: termina en `Z` o en un desfase `+hh:mm` (el servidor
/// manda `-03:00`). Sin zona, `DateTime.parse` lo tomaría como hora del
/// dispositivo y correría la hora en silencio.
final RegExp _zonePattern = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

DateTime _parseInstant(String value) {
  if (!_zonePattern.hasMatch(value)) {
    throw FormatException('Instante sin zona horaria', value);
  }
  return DateTime.parse(value);
}

/// Un aviso interno del socio (RNF-23): `GET /api/notificaciones`.
///
/// [type] es uno de `AGENDA`, `CANCELACION`, `SUSPENSION`,
/// `HISTORIA_ACTUALIZADA` o `RECORDATORIO`. Un tipo que el cliente no conoce
/// se muestra igual (con un ícono genérico): el servidor es quien lo define.
/// [title] lo deriva el servidor del tipo. [consultaId] hoy siempre viene
/// informado (todo aviso cuelga de una consulta), pero el contrato pide
/// tolerar `null` o la ausencia de la clave: un aviso sin consulta se muestra
/// igual y no se puede abrir. [createdAt] es un instante: para mostrarlo se
/// pasa por `UruguayTime.toUruguay`. [atencionId] es el id de la atención
/// (el mismo de `GET /api/historia-clinica/{idAtencion}`): solo lo trae un
/// aviso `HISTORIA_ACTUALIZADA` con atención. En el resto es `null`, y un
/// servidor que todavía no manda la clave también se lee como `null`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.consultaId,
    required this.content,
    required this.createdAt,
    this.atencionId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        type: json['tipo'] as String,
        title: json['titulo'] as String,
        consultaId: json['consultaId'] as int?,
        content: json['contenido'] as String,
        createdAt: _parseInstant(json['creadaEn'] as String),
        atencionId: json['atencionId'] as int?,
      );

  final int id;
  final String type;
  final String title;
  final int? consultaId;
  final int? atencionId;
  final String content;
  final DateTime createdAt;
}
