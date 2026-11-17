import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_support.dart';

void main() {
  test('el detalle de administración trae todo lo de la semilla', () async {
    final repo = FakeAnnouncementsRepository(
      now: () => kAdminTestNow,
      seed: adminTestSeed(),
    );

    final vigente = await repo.adminDetail(30);
    expect(vigente.title, 'Jornada de vacunación');
    expect(vigente.text, 'Texto 30');
    expect(vigente.status, AnnouncementStatus.active);
    expect(vigente.position, 2);
    expect(vigente.visibleFrom, isNull);
    expect(vigente.visibleUntil, DateTime.utc(2026, 12, 1, 3));

    final programada = await repo.adminDetail(20);
    expect(programada.status, AnnouncementStatus.scheduled);
    expect(programada.visibleFrom, DateTime.utc(2026, 11, 20, 3));
    expect(programada.position, isNull);

    final vencida = await repo.adminDetail(10);
    expect(vencida.status, AnnouncementStatus.expired);
    expect(vencida.text, 'Texto 10');
  });

  test('el detalle de administración de un id inexistente es 404', () {
    final repo = FakeAnnouncementsRepository(
      now: () => kAdminTestNow,
      seed: adminTestSeed(),
    );
    expect(repo.adminDetail(99), throwsA(isA<AnnouncementNotFoundException>()));
  });

  test('la semilla por defecto trae una programada y una vencida con texto e '
      'imágenes, y el detalle público no las entrega', () async {
    final repo = FakeAnnouncementsRepository(now: () => kAdminTestNow);

    final rows = {for (final r in await repo.adminList()) r.id: r};
    expect(rows[1]!.status, AnnouncementStatus.active);
    expect(rows[2]!.status, AnnouncementStatus.scheduled);
    expect(rows[3]!.status, AnnouncementStatus.expired);

    final programada = await repo.adminDetail(2);
    expect(programada.text, isNotEmpty);
    expect(programada.images, isNotEmpty);
    expect(programada.visibleFrom, isNotNull);

    final vencida = await repo.adminDetail(3);
    expect(vencida.text, isNotEmpty);
    expect(vencida.images, isNotEmpty);
    expect(vencida.visibleUntil, isNotNull);

    // La regla del servidor: fuera de vigencia, el público responde 404.
    await expectLater(
      repo.detail(2),
      throwsA(isA<AnnouncementNotFoundException>()),
    );
    await expectLater(
      repo.detail(3),
      throwsA(isA<AnnouncementNotFoundException>()),
    );
    expect((await repo.list()).items.map((i) => i.id), [1]);
  });
}
