import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../models/admin_announcement.dart';
import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_page.dart';
import '../repositories/announcements_repository.dart';
import '../repositories/api_announcements_repository.dart';
import '../repositories/fake_announcements_repository.dart';

/// El reloj con que los formularios de la cartelera validan el fin de la
/// visibilidad; se reemplaza en pruebas.
final announcementClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final announcementsRepositoryProvider = FutureProvider<AnnouncementsRepository>(
  (ref) async {
    if (ref.watch(useFakesProvider)) return FakeAnnouncementsRepository();
    return ApiAnnouncementsRepository(await ref.watch(dioProvider.future));
  },
);

final announcementsPageProvider = FutureProvider.autoDispose
    .family<AnnouncementPage, int>((ref, page) async {
      final session = ref.watch(
        sessionProvider.select((s) => (s.status, s.accessToken)),
      );
      if (session.$1 != SessionStatus.authenticated) {
        throw const ApiException('Iniciá sesión para consultar las novedades.');
      }
      return (await ref.watch(announcementsRepositoryProvider.future))
          .list(page: page);
    }, retry: (_, _) => null);

/// Cada apertura obtiene enlaces nuevos. La sesión y su renovación siguen
/// a cargo del Dio compartido; no hay reintentos de red en segundo plano.
final announcementDetailProvider = FutureProvider.autoDispose
    .family<AnnouncementDetail, int>((ref, id) async {
      final session = ref.watch(
        sessionProvider.select((s) => (s.status, s.accessToken)),
      );
      if (session.$1 != SessionStatus.authenticated) {
        throw const ApiException('Iniciá sesión para consultar la novedad.');
      }
      if (id <= 0) throw const AnnouncementNotFoundException();
      return (await ref.watch(announcementsRepositoryProvider.future))
          .detail(id);
    }, retry: (_, _) => null);

/// Sin reintentos automáticos: Inicio ofrece un reintento explícito.
/// Observar la sesión invalida respuestas anteriores al cambiar de usuario.
final latestAnnouncementsProvider =
    FutureProvider.autoDispose<List<Announcement>>((ref) async {
      final (status, _, _) = ref.watch(
        sessionProvider.select((s) => (s.status, s.role, s.accessToken)),
      );
      if (status != SessionStatus.authenticated) {
        return const [];
      }
      final repository = await ref.watch(
        announcementsRepositoryProvider.future,
      );
      return repository.carousel();
    }, retry: (_, _) => null);

/// El listado de administración: todas las novedades con su estado y su
/// posición. Solo el administrador. Sin reintentos automáticos: la pantalla
/// ofrece un reintento explícito.
final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<AdminAnnouncement>>((ref) async {
      final (status, role, _) = ref.watch(
        sessionProvider.select((s) => (s.status, s.role, s.accessToken)),
      );
      if (status != SessionStatus.authenticated) return const [];
      if (role != UserRole.administrador) {
        throw const ApiException(
          'Solo el administrador puede gestionar la cartelera.',
        );
      }
      final repository = await ref.watch(
        announcementsRepositoryProvider.future,
      );
      return repository.adminList();
    }, retry: (_, _) => null);

/// La selección guardada del carrusel. Solo el administrador.
final adminCarouselProvider = FutureProvider.autoDispose<List<CarouselSlot>>((
  ref,
) async {
  final (status, role, _) = ref.watch(
    sessionProvider.select((s) => (s.status, s.role, s.accessToken)),
  );
  if (status != SessionStatus.authenticated) return const [];
  if (role != UserRole.administrador) {
    throw const ApiException(
      'Solo el administrador puede gestionar la cartelera.',
    );
  }
  final repository = await ref.watch(announcementsRepositoryProvider.future);
  return repository.adminCarousel();
}, retry: (_, _) => null);

/// Lo que cambia cuando el administrador modifica la cartelera: su listado,
/// lo que ven los demás y el carrusel del Inicio.
void invalidateAnnouncementViews(WidgetRef ref) {
  ref.invalidate(adminAnnouncementsProvider);
  ref.invalidate(adminCarouselProvider);
  ref.invalidate(announcementsPageProvider);
  ref.invalidate(announcementDetailProvider);
  ref.invalidate(latestAnnouncementsProvider);
}
