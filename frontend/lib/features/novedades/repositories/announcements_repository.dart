import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_page.dart';
import '../../../core/network/api_exception.dart';

class AnnouncementNotFoundException extends ApiException {
  const AnnouncementNotFoundException() : super('No encontramos esta novedad.');
}

abstract interface class AnnouncementsRepository {
  /// Las novedades del carrusel del Inicio, en el orden que eligió el
  /// administrador. Vacía si no eligió ninguna.
  Future<List<Announcement>> carousel();
  Future<AnnouncementPage> list({int page = 0});
  Future<AnnouncementDetail> detail(int id);
  Future<void> publish(AnnouncementDraft draft);
}
