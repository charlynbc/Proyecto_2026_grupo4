import '../models/device_registration.dart';
import 'device_repository.dart';

/// Registro en memoria (`USE_FAKES=true`): no toca Firebase ni la red. Se
/// pierde al recargar la app.
class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  final Map<String, _Entry> _entries = {};
  int _nextId = 1;

  /// Los tokens habilitados, en orden de registro.
  List<String> get enabledTokens => [
    for (final entry in _entries.entries)
      if (entry.value.enabled) entry.key,
  ];

  @override
  Future<DeviceRegistration> register(String token) async {
    await Future<void>.delayed(latency);
    _requireToken(token);

    final existing = _entries[token];
    if (existing == null) {
      final entry = _Entry(_nextId++, _clock().toUtc());
      _entries[token] = entry;
      return entry.toRegistration(created: true);
    }
    if (!existing.enabled) {
      existing
        ..enabled = true
        ..registeredAt = _clock().toUtc();
    }
    return existing.toRegistration(created: false);
  }

  @override
  Future<void> deactivate(String token) async {
    await Future<void>.delayed(latency);
    _requireToken(token);
    _entries[token]?.enabled = false;
  }

  void _requireToken(String token) {
    if (token.trim().isEmpty) {
      throw const DeviceException(
        DeviceFailure.validation,
        'No pudimos identificar este dispositivo para las notificaciones.',
      );
    }
  }
}

class _Entry {
  _Entry(this.id, this.registeredAt);

  final int id;
  DateTime registeredAt;
  bool enabled = true;

  DeviceRegistration toRegistration({required bool created}) =>
      DeviceRegistration(
        id: id,
        enabled: enabled,
        registeredAt: registeredAt,
        created: created,
      );
}
