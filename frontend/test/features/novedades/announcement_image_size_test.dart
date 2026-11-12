import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/home/widgets/announcements_carousel.dart';
import 'package:agenda_medica/features/novedades/announcement_image_provider.dart';
import 'package:agenda_medica/features/novedades/announcement_images.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:agenda_medica/features/novedades/screens/announcements_screen.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.socio,
    accessToken: 'test-session',
  );
}

class _OneCover implements AnnouncementsRepository {
  @override
  Future<List<Announcement>> latest() async => const [];

  @override
  Future<AnnouncementPage> list({int page = 0}) async => AnnouncementPage(
    items: [
      Announcement(
        id: 7,
        title: 'Con portada',
        publishedAt: DateTime.utc(2026, 11, 1),
        coverUrl: 'https://example.invalid/portada-7.png',
        coverImageId: 77,
      ),
    ],
    page: 0,
    total: 1,
  );

  @override
  Future<AnnouncementDetail> detail(int id) => throw UnimplementedError();

  @override
  Future<void> publish(AnnouncementDraft draft) => throw UnimplementedError();
}

/// El proveedor del `Image` que hay en pantalla, que tiene que ser el de las
/// imágenes de novedad (caché por id de imagen).
AnnouncementImageProvider _shown(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image)).image;
  expect(image, isA<AnnouncementImageProvider>());
  return image as AnnouncementImageProvider;
}

void main() {
  test('el ancho de decodificación único es de 1280 píxeles', () {
    expect(kAnnouncementImageCacheWidth, 1280);
  });

  testWidgets('el carrusel decodifica la portada a 1280 y la guarda por id', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementsCarousel(
            announcements: [
              Announcement(
                id: 1,
                publishedAt: DateTime.utc(2026, 11, 1),
                coverUrl: 'https://example.invalid/portada-1.png',
                coverImageId: 11,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final shown = _shown(tester);
    expect(shown.cacheWidth, 1280);
    expect(shown.imageId, 11);
    expect(shown.url, 'https://example.invalid/portada-1.png');
  });

  testWidgets('la fila de la Cartelera decodifica la portada a 1280 y la '
      'guarda por id', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_Session.new),
          announcementsRepositoryProvider.overrideWith(
            (ref) async => _OneCover(),
          ),
        ],
        child: const MaterialApp(
          home: AnnouncementsScreen(role: UserRole.socio),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shown = _shown(tester);
    expect(shown.cacheWidth, 1280);
    expect(shown.imageId, 77);
    expect(shown.url, 'https://example.invalid/portada-7.png');
  });

  testWidgets('la galería del detalle decodifica la imagen a 1280 y la guarda '
      'por id', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementGallery(
            images: const [
              AnnouncementImage(
                id: 3,
                order: 0,
                url: 'https://example.invalid/imagen-3.png',
              ),
            ],
            onReload: () {},
          ),
        ),
      ),
    );

    final shown = _shown(tester);
    expect(shown.cacheWidth, 1280);
    expect(shown.imageId, 3);
    expect(shown.url, 'https://example.invalid/imagen-3.png');
  });

  testWidgets('el carrusel, la fila y el detalle usan la misma clave para la '
      'misma imagen', (tester) async {
    // La portada de una novedad es una de las imágenes del detalle: mismo id.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementsCarousel(
            announcements: [
              Announcement(
                id: 1,
                publishedAt: DateTime.utc(2026, 11, 1),
                coverUrl: 'https://example.invalid/portada?firma=A',
                coverImageId: 21,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );
    final fromCarousel = _shown(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnnouncementGallery(
              images: const [
                AnnouncementImage(
                  id: 21,
                  order: 0,
                  url: 'https://example.invalid/portada?firma=B',
                ),
              ],
              onReload: () {},
            ),
          ),
        ),
      ),
    );
    final fromGallery = _shown(tester);

    expect(fromCarousel == fromGallery, isTrue);
    expect(fromCarousel.hashCode, fromGallery.hashCode);
  });

  testWidgets('una portada sin id cae en la caché por URL con el mismo ancho', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnnouncementsCarousel(
            announcements: [
              Announcement(
                id: 1,
                publishedAt: DateTime.utc(2026, 11, 1),
                coverUrl: 'https://example.invalid/portada-1.png',
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image)).image;
    expect(image, isA<ResizeImage>());
    expect((image as ResizeImage).width, 1280);
  });
}
