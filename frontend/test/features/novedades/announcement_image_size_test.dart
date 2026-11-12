import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/home/widgets/announcements_carousel.dart';
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

/// El ancho de decodificación y la URL con que se creó el [Image] que hay en
/// pantalla, o falla si no está dentro de un `ResizeImage`.
({int? width, int? height, String url}) _decoded(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image)).image;
  expect(image, isA<ResizeImage>());
  final resize = image as ResizeImage;
  return (
    width: resize.width,
    height: resize.height,
    url: (resize.imageProvider as NetworkImage).url,
  );
}

void main() {
  test('el ancho de decodificación único es de 1280 píxeles', () {
    expect(kAnnouncementImageCacheWidth, 1280);
  });

  testWidgets('el carrusel decodifica la portada a 1280 de ancho', (
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

    final decoded = _decoded(tester);
    expect(decoded.width, 1280);
    expect(decoded.height, isNull);
    expect(decoded.url, 'https://example.invalid/portada-1.png');
  });

  testWidgets('la fila de la Cartelera decodifica la portada a 1280 de ancho', (
    tester,
  ) async {
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

    final decoded = _decoded(tester);
    expect(decoded.width, 1280);
    expect(decoded.height, isNull);
    expect(decoded.url, 'https://example.invalid/portada-7.png');
  });

  testWidgets('la galería del detalle decodifica la imagen a 1280 de ancho', (
    tester,
  ) async {
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

    final decoded = _decoded(tester);
    expect(decoded.width, 1280);
    expect(decoded.height, isNull);
    expect(decoded.url, 'https://example.invalid/imagen-3.png');
  });
}
