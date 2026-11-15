import '../models/admin_announcement.dart';
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

  // Gestión de la cartelera: solo ADMINISTRADOR.

  /// Todas las novedades con su estado y su posición en el carrusel.
  Future<List<AdminAnnouncement>> adminList();

  /// Cambia la vigencia. El fin es obligatorio (el servidor responde 400 si
  /// falta) y va después del inicio o, sin inicio, después de ahora.
  Future<void> updateValidity(
    int id, {
    DateTime? from,
    required DateTime? until,
  });

  /// La selección guardada del carrusel, con sus huecos.
  Future<List<CarouselSlot>> adminCarousel();

  /// Reemplaza toda la selección del carrusel (hasta 5 posiciones, con
  /// huecos) y devuelve la que quedó guardada.
  Future<List<CarouselSlot>> saveCarousel(List<CarouselSlot> slots);

  /// Elimina la novedad para siempre, con sus imágenes y su posición.
  Future<void> delete(int id);
}
