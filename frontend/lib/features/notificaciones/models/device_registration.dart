/// Respuesta de `POST /api/dispositivos` (contrato fila 33): el dispositivo
/// registrado. [created] es `true` si el servidor creó la fila (201) y `false`
/// si ya existía, se reasignó o se volvió a habilitar (200).
class DeviceRegistration {
  const DeviceRegistration({
    required this.id,
    required this.enabled,
    required this.registeredAt,
    required this.created,
  });

  /// Lanza [FormatException] o [TypeError] si falta un campo o no tiene el
  /// tipo esperado; el repository lo traduce al error genérico.
  factory DeviceRegistration.fromJson(
    Map<String, dynamic> json, {
    required bool created,
  }) => DeviceRegistration(
    id: json['id'] as int,
    enabled: json['habilitado'] as bool,
    registeredAt: DateTime.parse(json['registradoEn'] as String).toUtc(),
    created: created,
  );

  final int id;
  final bool enabled;
  final DateTime registeredAt;
  final bool created;
}
