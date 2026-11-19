import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement_detail.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _json({Map<String, Object?> override = const {}}) => {
  'id': 42,
  'titulo': 'Campaña de vacunación',
  'resumen': 'Resumen corto',
  'texto': '**Comienza** el lunes',
  'publicadoEn': '2026-11-01T10:00:00-03:00',
  'vigenteDesde': null,
  'vigenteHasta': '2026-11-10T00:00:00-03:00',
  'estado': 'VENCIDO',
  'posicion': null,
  'imagenes': [
    {'id': 101, 'orden': 0, 'url': 'https://almacen.example/101'},
  ],
  ...override,
};

void main() {
  test('lee todos los campos de una novedad vencida', () {
    final detail = AdminAnnouncementDetail.fromJson(_json());

    expect(detail.id, 42);
    expect(detail.title, 'Campaña de vacunación');
    expect(detail.summary, 'Resumen corto');
    expect(detail.text, '**Comienza** el lunes');
    expect(detail.publishedAt.toUtc(), DateTime.utc(2026, 11, 1, 13));
    expect(detail.visibleFrom, isNull);
    expect(detail.visibleUntil!.toUtc(), DateTime.utc(2026, 11, 10, 3));
    expect(detail.status, AnnouncementStatus.expired);
    expect(detail.position, isNull);
    expect(detail.images, hasLength(1));
    expect(detail.images.single.id, 101);
    expect(detail.images.single.order, 0);
    expect(detail.images.single.url, 'https://almacen.example/101');
  });

  test('lee una programada con inicio y una vigente con posición', () {
    final scheduled = AdminAnnouncementDetail.fromJson(
      _json(
        override: {
          'estado': 'PROGRAMADO',
          'vigenteDesde': '2027-01-10T00:00:00-03:00',
          'vigenteHasta': '2027-02-10T00:00:00-03:00',
        },
      ),
    );
    expect(scheduled.status, AnnouncementStatus.scheduled);
    expect(scheduled.visibleFrom!.toUtc(), DateTime.utc(2027, 1, 10, 3));

    final active = AdminAnnouncementDetail.fromJson(
      _json(override: {'estado': 'VIGENTE', 'posicion': 2}),
    );
    expect(active.status, AnnouncementStatus.active);
    expect(active.position, 2);
  });

  test('titulo, resumen, texto e imágenes ausentes o nulos no rompen', () {
    final detail = AdminAnnouncementDetail.fromJson(
      _json(
        override: {
          'titulo': null,
          'resumen': null,
          'texto': null,
          'imagenes': null,
        },
      ),
    );
    expect(detail.title, isNull);
    expect(detail.summary, isNull);
    expect(detail.text, isNull);
    expect(detail.images, isEmpty);
    expect(detail.displayTitle, 'Novedad de la mutualista');

    final sinCampos = AdminAnnouncementDetail.fromJson({
      'id': 5,
      'publicadoEn': '2026-11-01T10:00:00-03:00',
      'estado': 'VIGENTE',
    });
    expect(sinCampos.images, isEmpty);
    expect(sinCampos.visibleUntil, isNull);
  });

  test('un estado desconocido, un id inválido o una posición fuera de rango '
      'se rechazan', () {
    expect(
      () => AdminAnnouncementDetail.fromJson(_json(override: {'estado': 'X'})),
      throwsFormatException,
    );
    expect(
      () => AdminAnnouncementDetail.fromJson(_json(override: {'id': 0})),
      throwsFormatException,
    );
    expect(
      () => AdminAnnouncementDetail.fromJson(_json(override: {'posicion': 6})),
      throwsFormatException,
    );
  });
}
