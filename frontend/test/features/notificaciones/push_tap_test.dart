import 'package:agenda_medica/features/notificaciones/models/push_tap.dart';
import 'package:agenda_medica/features/notificaciones/services/push_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushTap.fromData', () {
    test('lee tipo, notificacionId y atencionId, que llegan como texto', () {
      final tap = PushTap.fromData({
        'tipo': 'HISTORIA_ACTUALIZADA',
        'notificacionId': '15002',
        'atencionId': '4100',
      });

      expect(tap.type, 'HISTORIA_ACTUALIZADA');
      expect(tap.notificationId, 15002);
      expect(tap.atencionId, 4100);
    });

    test('sin la clave atencionId queda en null', () {
      final tap = PushTap.fromData({
        'tipo': 'AGENDA',
        'notificacionId': '15001',
      });

      expect(tap.type, 'AGENDA');
      expect(tap.atencionId, isNull);
    });

    test(
      'un atencionId que no es un entero positivo se trata como ausente',
      () {
        for (final invalid in [
          'abc',
          '',
          '0',
          '-3',
          '1.5',
          '12abc',
          ' 12',
          '+4',
        ]) {
          final tap = PushTap.fromData({
            'tipo': 'HISTORIA_ACTUALIZADA',
            'notificacionId': '15002',
            'atencionId': invalid,
          });

          expect(tap.atencionId, isNull, reason: 'atencionId "$invalid"');
        }
      },
    );

    test('un notificacionId inválido o ausente queda en null', () {
      expect(
        PushTap.fromData({'tipo': 'AGENDA', 'notificacionId': 'x'})
            .notificationId,
        isNull,
      );
      expect(PushTap.fromData({'tipo': 'AGENDA'}).notificationId, isNull);
    });

    test(
      'un tipo ausente queda como texto vacío y uno desconocido se conserva',
      () {
        expect(PushTap.fromData({}).type, '');
        expect(PushTap.fromData({'tipo': 'OTRO'}).type, 'OTRO');
      },
    );

    test('tolera valores que no son texto', () {
      final tap = PushTap.fromData({
        'tipo': 'HISTORIA_ACTUALIZADA',
        'notificacionId': 15002,
        'atencionId': 4100,
      });

      expect(tap.notificationId, 15002);
      expect(tap.atencionId, 4100);
    });
  });

  group('destinationForPush', () {
    test('historia con atención abre Avisos y encima el detalle', () {
      expect(
        destinationForPush(
          const PushTap(
            type: 'HISTORIA_ACTUALIZADA',
            notificationId: 15002,
            atencionId: 4100,
          ),
        ),
        ['/socio/avisos', '/socio/historia/4100'],
      );
    });

    test('historia sin atención abre solo Avisos', () {
      expect(
        destinationForPush(
          const PushTap(type: 'HISTORIA_ACTUALIZADA', notificationId: 15002),
        ),
        ['/socio/avisos'],
      );
    });

    test('cualquier otro tipo abre solo Avisos, aunque traiga atencionId', () {
      for (final type in [
        'AGENDA',
        'CANCELACION',
        'SUSPENSION',
        'RECORDATORIO',
        'OTRO',
        '',
      ]) {
        expect(destinationForPush(PushTap(type: type, atencionId: 7)), [
          '/socio/avisos',
        ], reason: 'tipo "$type"');
      }
    });
  });
}
