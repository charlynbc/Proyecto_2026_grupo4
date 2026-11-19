import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _json({
  Object? id = 42,
  Object? titulo = 'Vacunación',
  Object? estado = 'VIGENTE',
  Object? desde,
  Object? hasta = '2026-12-01T00:00:00-03:00',
  Object? posicion,
}) => {
  'id': id,
  'titulo': titulo,
  'publicadoEn': '2026-11-03T12:00:00Z',
  'vigenteDesde': desde,
  'vigenteHasta': hasta,
  'estado': estado,
  'posicion': posicion,
};

void main() {
  group('AdminAnnouncement.fromJson', () {
    test('lee todos los campos con posición', () {
      final item = AdminAnnouncement.fromJson(
        _json(desde: '2026-11-03T00:00:00-03:00', posicion: 3),
      );

      expect(item.id, 42);
      expect(item.displayTitle, 'Vacunación');
      expect(item.publishedAt, DateTime.utc(2026, 11, 3, 12));
      expect(item.visibleFrom, DateTime.utc(2026, 11, 3, 3));
      expect(item.visibleUntil, DateTime.utc(2026, 12, 1, 3));
      expect(item.status, AnnouncementStatus.active);
      expect(item.position, 3);
    });

    test('sin inicio, sin fin y sin posición quedan nulos', () {
      final item = AdminAnnouncement.fromJson(_json(hasta: null));

      expect(item.visibleFrom, isNull);
      expect(item.visibleUntil, isNull);
      expect(item.position, isNull);
    });

    test('un título nulo usa el título genérico', () {
      expect(
        AdminAnnouncement.fromJson(_json(titulo: null)).displayTitle,
        'Novedad de la mutualista',
      );
    });

    for (final (api, status, label) in [
      ('PROGRAMADO', AnnouncementStatus.scheduled, 'Programado'),
      ('VIGENTE', AnnouncementStatus.active, 'Vigente'),
      ('VENCIDO', AnnouncementStatus.expired, 'Vencido'),
    ]) {
      test('el estado $api es ${status.name} y se muestra "$label"', () {
        final item = AdminAnnouncement.fromJson(_json(estado: api));

        expect(item.status, status);
        expect(item.status.label, label);
      });
    }

    for (final bad in [
      _json(estado: 'ELIMINADO'),
      _json(estado: null),
      _json(id: 0),
      _json(id: 'x'),
      _json(posicion: 6),
      _json(posicion: 0),
    ]) {
      test('un dato inválido es FormatException o TypeError: $bad', () {
        expect(
          () => AdminAnnouncement.fromJson(bad),
          throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
        );
      });
    }
  });

  group('CarouselSlot', () {
    test('lee y escribe posicion y anuncioId', () {
      final slot = CarouselSlot.fromJson({'posicion': 3, 'anuncioId': 56});

      expect(slot.position, 3);
      expect(slot.announcementId, 56);
      expect(slot.toJson(), {'posicion': 3, 'anuncioId': 56});
    });
  });

  group('AnnouncementDraft.validateVisibilityRange', () {
    final now = DateTime.utc(2026, 11, 14, 15);

    test('el mismo mensaje del servidor si falta el fin', () {
      expect(
        AnnouncementDraft.validateVisibilityRange(null, null, now),
        'La fecha de fin es obligatoria y debe ser posterior al inicio',
      );
    });

    test('fin igual al inicio no es válido', () {
      final same = DateTime.utc(2026, 12, 1, 3);
      expect(
        AnnouncementDraft.validateVisibilityRange(same, same, now),
        isNotNull,
      );
    });

    test('un fin posterior al inicio es válido', () {
      expect(
        AnnouncementDraft.validateVisibilityRange(
          DateTime.utc(2026, 12, 1, 3),
          DateTime.utc(2026, 12, 2, 3),
          now,
        ),
        isNull,
      );
    });
  });
}
