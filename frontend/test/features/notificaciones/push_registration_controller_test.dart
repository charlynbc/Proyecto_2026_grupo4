import 'dart:async';

import 'package:agenda_medica/features/notificaciones/repositories/device_repository.dart';
import 'package:agenda_medica/features/notificaciones/services/push_notification_service.dart';
import 'package:agenda_medica/features/notificaciones/services/push_registration_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'push_test_support.dart';

PushRegistrationController _controller(
  PushNotificationService service,
  DeviceRepository devices, {
  Duration timeout = const Duration(seconds: 3),
}) => PushRegistrationController(
  service: service,
  devices: () async => devices,
  deactivateTimeout: timeout,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('start', () {
    test('registra el token que entrega el servicio', () async {
      final devices = RecordingDeviceRepository();

      await _controller(FakePushService(), devices).start();

      expect(devices.events, ['register:fcm-token-1']);
    });

    test('sin token (permiso denegado) no registra nada', () async {
      final devices = RecordingDeviceRepository();

      await _controller(FakePushService(token: null), devices).start();

      expect(devices.events, isEmpty);
    });

    test(
      'con el servicio que no hace nada (web o fakes) no registra nada',
      () async {
        final devices = RecordingDeviceRepository();

        await _controller(const NoopPushNotificationService(), devices).start();

        expect(devices.events, isEmpty);
      },
    );

    test('si Firebase renueva el token, lo registra de nuevo', () async {
      final service = FakePushService();
      final devices = RecordingDeviceRepository();
      await _controller(service, devices).start();

      service.refreshes.add('fcm-token-2');
      await _settle();

      expect(devices.events, ['register:fcm-token-1', 'register:fcm-token-2']);
    });

    test(
      'un segundo start no duplica el registro de las renovaciones',
      () async {
        final service = FakePushService();
        final devices = RecordingDeviceRepository();
        final controller = _controller(service, devices);
        await controller.start();
        await controller.start();
        devices.events.clear();

        service.refreshes.add('fcm-token-2');
        await _settle();

        expect(devices.events, ['register:fcm-token-2']);
      },
    );

    test('si el registro falla no propaga el error y sigue atento a las renovaciones', () async {
      final service = FakePushService();
      final devices = RecordingDeviceRepository(
        error: const DeviceException(DeviceFailure.other),
      );
      final controller = _controller(service, devices);

      await controller.start();
      service.refreshes.add('fcm-token-2');
      await _settle();

      expect(devices.events, ['register:fcm-token-1', 'register:fcm-token-2']);
    });

    test(
      'si se corta la sesión mientras espera el token, no registra',
      () async {
        final service = FakePushService()..pendingToken = Completer<String?>();
        final devices = RecordingDeviceRepository();
        final controller = _controller(service, devices);

        final starting = controller.start();
        controller.stop();
        service.pendingToken!.complete('fcm-token-1');
        await starting;

        expect(devices.events, isEmpty);
      },
    );
  });

  group('stop', () {
    test('deja de registrar las renovaciones de token', () async {
      final service = FakePushService();
      final devices = RecordingDeviceRepository();
      final controller = _controller(service, devices);
      await controller.start();
      devices.events.clear();

      controller.stop();
      service.refreshes.add('fcm-token-2');
      await _settle();

      expect(devices.events, isEmpty);
    });
  });

  group('deactivate', () {
    test('da de baja el último token registrado', () async {
      final service = FakePushService();
      final devices = RecordingDeviceRepository();
      final controller = _controller(service, devices);
      await controller.start();
      service.refreshes.add('fcm-token-2');
      await _settle();
      devices.events.clear();

      await controller.deactivate();

      expect(devices.events, ['deactivate:fcm-token-2']);
    });

    test('sin token registrado no llama a la API', () async {
      final devices = RecordingDeviceRepository();

      await _controller(FakePushService(), devices).deactivate();

      expect(devices.events, isEmpty);
    });

    test('después de la baja ya no se registran renovaciones', () async {
      final service = FakePushService();
      final devices = RecordingDeviceRepository();
      final controller = _controller(service, devices);
      await controller.start();
      await controller.deactivate();
      devices.events.clear();

      service.refreshes.add('fcm-token-2');
      await _settle();

      expect(devices.events, isEmpty);
    });

    test('un segundo deactivate no repite la baja', () async {
      final devices = RecordingDeviceRepository();
      final controller = _controller(FakePushService(), devices);
      await controller.start();

      await controller.deactivate();
      await controller.deactivate();

      expect(devices.events, [
        'register:fcm-token-1',
        'deactivate:fcm-token-1',
      ]);
    });

    test('si la baja falla no propaga el error', () async {
      final devices = RecordingDeviceRepository(
        error: const DeviceException(DeviceFailure.unauthenticated),
      );
      final controller = _controller(FakePushService(), devices);
      await controller.start();

      await controller.deactivate();

      expect(devices.events, [
        'register:fcm-token-1',
        'deactivate:fcm-token-1',
      ]);
    });

    test('si la baja no responde, vence el timeout y termina', () async {
      final devices = RecordingDeviceRepository(hang: Completer<void>());
      final controller = _controller(
        FakePushService(),
        devices,
        timeout: const Duration(milliseconds: 20),
      );
      await controller.start();

      final stopwatch = Stopwatch()..start();
      await controller.deactivate();
      stopwatch.stop();

      expect(devices.events, [
        'register:fcm-token-1',
        'deactivate:fcm-token-1',
      ]);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });
}
