import 'package:agenda_medica/features/notificaciones/services/push_notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushNotificationService', () {
    test('isSupported es false sin VAPID key', () {
      final service = PushNotificationService(Dio(), vapidKey: '');
      expect(service.isSupported, isFalse);
    });

    test('register() devuelve false si no es soportado', () async {
      final service = PushNotificationService(Dio(), vapidKey: '');
      expect(await service.register(), isFalse);
    });

    test('foregroundMessages es un stream vacío si no es soportado', () async {
      final service = PushNotificationService(Dio(), vapidKey: '');
      expect(await service.foregroundMessages.isEmpty, isTrue);
    });
  });
}
