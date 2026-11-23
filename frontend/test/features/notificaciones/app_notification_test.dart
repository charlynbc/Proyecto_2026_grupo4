import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification_page.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({bool withAtencion = true, Object? atencionId}) => {
  'id': 15002,
  'tipo': 'HISTORIA_ACTUALIZADA',
  'titulo': 'Historia clínica actualizada',
  'consultaId': 9000,
  'contenido': 'Se registró la atención de tu consulta.',
  'creadaEn': '2026-10-15T09:40:00-03:00',
  if (withAtencion) 'atencionId': atencionId,
};

void main() {
  group('AppNotification.atencionId', () {
    test('con la clave presente lee el id de la atención', () {
      final notification = AppNotification.fromJson(_json(atencionId: 4100));

      expect(notification.atencionId, 4100);
      expect(notification.consultaId, 9000);
    });

    test('con la clave en null queda en null', () {
      final notification = AppNotification.fromJson(_json(atencionId: null));

      expect(notification.atencionId, isNull);
    });

    test('con la clave ausente (backend viejo) queda en null', () {
      final notification = AppNotification.fromJson(_json(withAtencion: false));

      expect(notification.atencionId, isNull);
      expect(notification.type, 'HISTORIA_ACTUALIZADA');
    });

    test('el parseo de la página trae el atencionId de cada item', () {
      final page = AppNotificationPage.fromJson({
        'items': [
          _json(atencionId: 4100),
          {
            'id': 15001,
            'tipo': 'SUSPENSION',
            'titulo': 'Turno suspendido',
            'consultaId': 9001,
            'contenido': 'Se suspendió el turno.',
            'creadaEn': '2026-10-16T11:20:00-03:00',
            'atencionId': null,
          },
        ],
        'page': 0,
        'size': 20,
        'total': 2,
      });

      expect(page.items.map((n) => n.atencionId), [4100, null]);
    });

    test('un aviso construido a mano sin atencionId la deja en null', () {
      final notification = AppNotification(
        id: 1,
        type: 'AGENDA',
        title: 'Consulta agendada',
        consultaId: 7,
        content: 'Contenido.',
        createdAt: DateTime.utc(2026, 10, 1),
      );

      expect(notification.atencionId, isNull);
    });
  });
}
