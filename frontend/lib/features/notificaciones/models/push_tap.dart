/// Lo que se sabe de una notificación push que el socio tocó (o que le llegó
/// con la app abierta), reducido a los datos del mensaje.
///
/// El servidor manda siempre `tipo` y `notificacionId`; `atencionId` solo viene
/// en un `HISTORIA_ACTUALIZADA` con atención. Firebase entrega todos los
/// valores como texto, y una clave que no corresponde está ausente, no nula.
class PushTap {
  const PushTap({required this.type, this.notificationId, this.atencionId});

  /// Lee el mapa `data` de un mensaje push. Es tolerante: un valor que falta o
  /// no es un entero positivo queda en `null`, y un `tipo` ausente en `''`.
  factory PushTap.fromData(Map<String, dynamic> data) => PushTap(
    type: data['tipo']?.toString() ?? '',
    notificationId: _positiveInt(data['notificacionId']),
    atencionId: _positiveInt(data['atencionId']),
  );

  /// El `tipo` del aviso (`AGENDA`, `HISTORIA_ACTUALIZADA`...), o `''`.
  final String type;

  /// El `id` del aviso, el mismo de `GET /api/notificaciones`.
  final int? notificationId;

  /// El id de la atención; solo en un aviso de historia con atención.
  final int? atencionId;

  static int? _positiveInt(Object? value) {
    final text = value?.toString() ?? '';
    if (!RegExp(r'^\d+$').hasMatch(text)) return null;
    final number = int.tryParse(text);
    return number != null && number > 0 ? number : null;
  }

  @override
  bool operator ==(Object other) =>
      other is PushTap &&
      other.type == type &&
      other.notificationId == notificationId &&
      other.atencionId == atencionId;

  @override
  int get hashCode => Object.hash(type, notificationId, atencionId);

  @override
  String toString() =>
      'PushTap($type, notificacionId: $notificationId, atencionId: $atencionId)';
}
