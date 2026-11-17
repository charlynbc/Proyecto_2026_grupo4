import 'package:agenda_medica/features/notificaciones/repositories/device_repository.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_device_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeDeviceRepository _repo() => FakeDeviceRepository(
  latency: Duration.zero,
  clock: () => DateTime.utc(2026, 11, 14, 15),
);

void main() {
  test(
    'el primer registro de un token es nuevo, habilitado y con id 1',
    () async {
      final result = await _repo().register('fcm-token-1');

      expect(result.created, isTrue);
      expect(result.id, 1);
      expect(result.enabled, isTrue);
      expect(result.registeredAt, DateTime.utc(2026, 11, 14, 15));
    },
  );

  test(
    'registrar de nuevo el mismo token devuelve el mismo id, sin crear',
    () async {
      final repo = _repo();
      await repo.register('fcm-token-1');

      final again = await repo.register('fcm-token-1');

      expect(again.created, isFalse);
      expect(again.id, 1);
      expect(repo.enabledTokens, ['fcm-token-1']);
    },
  );

  test('un segundo token recibe el id 2', () async {
    final repo = _repo();
    await repo.register('fcm-token-1');

    final other = await repo.register('fcm-token-2');

    expect(other.created, isTrue);
    expect(other.id, 2);
    expect(repo.enabledTokens, ['fcm-token-1', 'fcm-token-2']);
  });

  test(
    'la baja deshabilita el token y registrar lo vuelve a habilitar',
    () async {
      final repo = _repo();
      await repo.register('fcm-token-1');

      await repo.deactivate('fcm-token-1');
      expect(repo.enabledTokens, isEmpty);

      final again = await repo.register('fcm-token-1');
      expect(again.created, isFalse);
      expect(again.enabled, isTrue);
      expect(repo.enabledTokens, ['fcm-token-1']);
    },
  );

  test('dar de baja un token desconocido no falla ni crea nada', () async {
    final repo = _repo();

    await repo.deactivate('fcm-token-que-no-existe');

    expect(repo.enabledTokens, isEmpty);
  });

  test('un token vacío o de solo espacios es validation', () async {
    for (final token in ['', '   ']) {
      await expectLater(
        _repo().register(token),
        throwsA(
          isA<DeviceException>().having(
            (e) => e.failure,
            'failure',
            DeviceFailure.validation,
          ),
        ),
      );
    }
  });
}
