import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el fake lista primero la última novedad publicada', () async {
    final repository = FakeAnnouncementsRepository();
    // Un fin en 2099: el Fake exige fin, como el servidor.
    final until = DateTime.utc(2099, 1, 1, 3);
    await repository.publish(
      AnnouncementDraft(
        title: 'Horarios de atención',
        text: 'Texto',
        visibleUntil: until,
      ),
    );
    await repository.publish(
      AnnouncementDraft(
        title: 'Campaña de vacunación',
        text: 'Texto',
        visibleUntil: until,
      ),
    );

    final page = await repository.list();
    expect(page.items.take(2).map((item) => item.title), [
      'Campaña de vacunación',
      'Horarios de atención',
    ]);
  });
}
