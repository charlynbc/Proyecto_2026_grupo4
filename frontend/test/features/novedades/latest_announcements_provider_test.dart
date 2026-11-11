import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Session extends SessionNotifier {
  _Session(this.status, this.role);

  final SessionStatus status;
  final UserRole? role;

  @override
  SessionState build() =>
      SessionState(status: status, role: role, accessToken: 'token-de-prueba');
}

class _Repo extends FakeAnnouncementsRepository {
  _Repo({this.error});

  final Object? error;
  int calls = 0;

  @override
  Future<List<Announcement>> latest() async {
    calls++;
    if (error != null) throw error!;
    return [
      Announcement(
        id: 7,
        title: 'Siete',
        publishedAt: DateTime.utc(2026, 11, 7),
      ),
      Announcement(
        id: 8,
        title: 'Ocho',
        publishedAt: DateTime.utc(2026, 11, 8),
      ),
    ];
  }
}

ProviderContainer _container(_Repo repo, SessionStatus status, UserRole? role) {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(() => _Session(status, role)),
      announcementsRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  addTearDown(container.dispose);
  container.listen(latestAnnouncementsProvider, (_, _) {});
  return container;
}

void main() {
  for (final role in UserRole.values) {
    test('${role.name} recibe las novedades del repositorio', () async {
      final repo = _Repo();
      final container = _container(repo, SessionStatus.authenticated, role);

      final result = await container.read(latestAnnouncementsProvider.future);

      expect([for (final item in result) item.id], [7, 8]);
      expect(repo.calls, 1);
    });
  }

  test(
    'sin sesión autenticada no pide nada y devuelve la lista vacía',
    () async {
      final repo = _Repo();
      final container = _container(repo, SessionStatus.unauthenticated, null);

      final result = await container.read(latestAnnouncementsProvider.future);

      expect(result, isEmpty);
      expect(repo.calls, 0);
    },
  );

  test('un error del repositorio llega al estado del provider', () async {
    final repo = _Repo(error: const ApiException('Sin permiso para ver.'));
    final container = _container(
      repo,
      SessionStatus.authenticated,
      UserRole.administrador,
    );

    await expectLater(
      container.read(latestAnnouncementsProvider.future),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Sin permiso para ver.',
        ),
      ),
    );
  });
}
