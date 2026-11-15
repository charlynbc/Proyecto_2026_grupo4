/// Un aviso interno del socio (RNF-23): `GET /api/notificaciones`.
///
/// [type] es uno de `AGENDA`, `CANCELACION`, `SUSPENSION`,
/// `HISTORIA_ACTUALIZADA` o `RECORDATORIO`. Un tipo que el cliente no conoce
/// se muestra igual (con un ícono genérico): el servidor es quien lo define.
/// [title] lo deriva el servidor del tipo. [consultaId] hoy siempre viene
/// informado (todo aviso cuelga de una consulta), pero el contrato pide
/// tolerar `null` o la ausencia de la clave: un aviso sin consulta se muestra
/// igual y no se puede abrir. [createdAt] es un instante: para mostrarlo se
/// pasa por `UruguayTime.toUruguay`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.consultaId,
    required this.content,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        type: json['tipo'] as String,
        title: json['titulo'] as String,
        consultaId: json['consultaId'] as int?,
        content: json['contenido'] as String,
        createdAt: DateTime.parse(json['creadaEn'] as String),
      );

  final int id;
  final String type;
  final String title;
  final int? consultaId;
  final String content;
  final DateTime createdAt;
}
