import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;

/// "Ahora" fijo de las pruebas de gestión: 14/11/2026 12:00 en Uruguay
/// (15:00 UTC).
final kAdminTestNow = DateTime.utc(2026, 11, 14, 15);

class AdminTestSession extends SessionNotifier {
  AdminTestSession(this.role);
  final UserRole role;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    role: role,
    accessToken: 'test-session',
  );
}

FakeAnnouncementEntry adminTestEntry(
  int id,
  String title, {
  required DateTime published,
  DateTime? from,
  DateTime? until,
  int? position,
}) => FakeAnnouncementEntry(
  detail: AnnouncementDetail(
    id: id,
    title: title,
    text: 'Texto $id',
    publishedAt: published,
  ),
  visibleFrom: from,
  visibleUntil: until,
  position: position,
);

/// Tres novedades: 30 vigente en la posición 2, 20 programada del 20/11 y 10
/// vencida.
List<FakeAnnouncementEntry> adminTestSeed() => [
  adminTestEntry(
    30,
    'Jornada de vacunación',
    published: DateTime.utc(2026, 11, 12, 12),
    until: DateTime.utc(2026, 12, 1, 3),
    position: 2,
  ),
  adminTestEntry(
    20,
    'Horarios de verano',
    published: DateTime.utc(2026, 11, 10, 12),
    from: DateTime.utc(2026, 11, 20, 3),
    until: DateTime.utc(2026, 11, 21, 2, 59),
  ),
  adminTestEntry(
    10,
    'Campaña anterior',
    published: DateTime.utc(2026, 10, 1, 12),
    until: DateTime.utc(2026, 11, 1, 3),
  ),
];

/// Un Fake con las reglas reales que además registra las llamadas y permite
/// demorar o hacer fallar cada operación de gestión.
class AdminTestRepo extends FakeAnnouncementsRepository {
  AdminTestRepo({List<FakeAnnouncementEntry>? seed})
    : super(now: () => kAdminTestNow, seed: seed ?? adminTestSeed());

  final calls = <String>[];
  int listCalls = 0;
  Object? listError;
  Completer<void>? listPending;

  Completer<void>? deletePending;
  ApiException? deleteError;

  final validityCalls = <({int id, DateTime? from, DateTime? until})>[];
  Completer<void>? validityPending;
  ApiException? validityError;

  int carouselReads = 0;
  Object? carouselReadError;
  Completer<void>? carouselReadPending;
  final saves = <List<CarouselSlot>>[];
  Completer<void>? savePending;
  ApiException? saveError;

  @override
  Future<List<AdminAnnouncement>> adminList() async {
    listCalls++;
    if (listError != null) throw listError!;
    if (listPending != null) await listPending!.future;
    return super.adminList();
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete:$id');
    if (deleteError != null) throw deleteError!;
    if (deletePending != null) await deletePending!.future;
    return super.delete(id);
  }

  @override
  Future<void> updateValidity(
    int id, {
    DateTime? from,
    required DateTime? until,
  }) async {
    validityCalls.add((id: id, from: from, until: until));
    if (validityError != null) throw validityError!;
    if (validityPending != null) await validityPending!.future;
    return super.updateValidity(id, from: from, until: until);
  }

  @override
  Future<List<CarouselSlot>> adminCarousel() async {
    carouselReads++;
    if (carouselReadError != null) throw carouselReadError!;
    if (carouselReadPending != null) await carouselReadPending!.future;
    return super.adminCarousel();
  }

  @override
  Future<List<CarouselSlot>> saveCarousel(List<CarouselSlot> slots) async {
    saves.add(List.of(slots));
    if (saveError != null) throw saveError!;
    if (savePending != null) await savePending!.future;
    return super.saveCarousel(slots);
  }

  final detailIds = <int>[];

  @override
  Future<AnnouncementDetail> detail(int id) {
    detailIds.add(id);
    return super.detail(id);
  }

  /// Otro administrador la eliminó entre que se cargó la pantalla y se tocó.
  Future<void> deleteBehindTheScenes(int id) => super.delete(id);
}

/// Monta la app en [location] (por defecto la Cartelera del rol) con el
/// repositorio [repo] y devuelve el contenedor.
Future<ProviderContainer> pumpAdminScreen(
  WidgetTester tester,
  AdminTestRepo repo, {
  double width = 1280,
  double scale = 1,
  UserRole role = UserRole.administrador,
  String? location,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(() => AdminTestSession(role)),
      announcementClockProvider.overrideWithValue(() => kAdminTestNow),
      accountRepositoryProvider.overrideWith(
        (ref) async => RecordingAccountRepository(),
      ),
      announcementsRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  addTearDown(() async {
    await unmountApp(tester);
    container.dispose();
  });
  final router = container.read(goRouterProvider)
    ..go(location ?? role.announcementsPath);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  final pendingLoad =
      repo.listPending != null || repo.carouselReadPending != null;
  if (!pendingLoad) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return container;
}
