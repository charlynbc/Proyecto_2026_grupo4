import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el fake lista primero la última novedad publicada', () async {
    final repository = FakeAnnouncementsRepository();
    await repository.publish(
      const AnnouncementDraft(title: 'Horarios de atención', text: 'Texto'),
    );
    await repository.publish(
      const AnnouncementDraft(title: 'Campaña de vacunación', text: 'Texto'),
    );

    final page = await repository.list();
    expect(page.items.take(2).map((item) => item.title), [
      'Campaña de vacunación',
      'Horarios de atención',
    ]);
  });
}
