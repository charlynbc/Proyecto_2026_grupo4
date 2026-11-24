import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/notificaciones/models/push_tap.dart';
import 'package:agenda_medica/features/notificaciones/services/push_navigation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'push_test_support.dart';

const _checking = SessionState(status: SessionStatus.checking);
const _loggedOut = SessionState(status: SessionStatus.unauthenticated);
const _socio = SessionState(
  status: SessionStatus.authenticated,
  accessToken: 'token',
  role: UserRole.socio,
);
const _medico = SessionState(
  status: SessionStatus.authenticated,
  accessToken: 'token',
  role: UserRole.medico,
);

const _historia = PushTap(
  type: 'HISTORIA_ACTUALIZADA',
  notificationId: 15002,
  atencionId: 4100,
);
const _agenda = PushTap(type: 'AGENDA', notificationId: 15001);

/// El controlador con una sesión que el test cambia a mano, y anotando a dónde
/// navega y cuántas veces refresca Avisos.
class _Harness {
  _Harness({this.session = _socio}) {
    controller = PushNavigationController(
      service: service,
      session: () => session,
      navigate: (routes) async => navigations.add(routes),
      refreshNotifications: () => refreshes++,
    );
  }

  final FakePushService service = FakePushService();
  SessionState session;
  final List<List<String>> navigations = [];
  int refreshes = 0;
  late final PushNavigationController controller;

  /// Cambia la sesión y avisa al controlador, como hace `main.dart`.
  void setSession(SessionState next) {
    session = next;
    controller.onSessionChanged(next);
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('con un socio autenticado', () {
    test('el toque inicial de historia abre Avisos y el detalle', () async {
      final h = _Harness()..service.initialTap = _historia;

      await h.controller.start();
      await _settle();

      expect(h.navigations, [
        ['/socio/avisos', '/socio/historia/4100'],
      ]);
      expect(h.refreshes, 1);
    });

    test('sin toque inicial no navega', () async {
      final h = _Harness();

      await h.controller.start();
      await _settle();

      expect(h.navigations, isEmpty);
      expect(h.refreshes, 0);
    });

    test(
      'el toque inicial se atiende una sola vez aunque se arranque dos veces',
      () async {
        final h = _Harness()..service.initialTap = _historia;

        await h.controller.start();
        await h.controller.start();
        await _settle();

        expect(h.navigations.length, 1);
      },
    );

    test('un toque en segundo plano de otro tipo abre solo Avisos', () async {
      final h = _Harness();
      await h.controller.start();

      h.service.tapEvents.add(_agenda);
      await _settle();

      expect(h.navigations, [
        ['/socio/avisos'],
      ]);
      expect(h.refreshes, 1);
    });

    test('un toque de historia sin atención abre solo Avisos', () async {
      final h = _Harness();
      await h.controller.start();

      h.service.tapEvents.add(
        const PushTap(type: 'HISTORIA_ACTUALIZADA', notificationId: 15002),
      );
      await _settle();

      expect(h.navigations, [
        ['/socio/avisos'],
      ]);
    });

    test('después de stop los toques ya no navegan', () async {
      final h = _Harness();
      await h.controller.start();
      h.controller.stop();

      h.service.tapEvents.add(_historia);
      await _settle();

      expect(h.navigations, isEmpty);
    });
  });

  group('destino pendiente sin sesión', () {
    test('un toque mientras se verifica la sesión espera y se consume al '
        'autenticarse un socio', () async {
      final h = _Harness(session: _checking);
      await h.controller.start();

      h.service.tapEvents.add(_historia);
      await _settle();
      expect(h.navigations, isEmpty);

      h.setSession(_socio);
      await _settle();

      expect(h.navigations, [
        ['/socio/avisos', '/socio/historia/4100'],
      ]);
      expect(h.refreshes, 1);
    });

    test('un toque sin sesión iniciada espera al login del socio', () async {
      final h = _Harness(session: _loggedOut);
      await h.controller.start();

      h.service.tapEvents.add(_agenda);
      await _settle();
      h.setSession(_loggedOut);
      await _settle();
      expect(h.navigations, isEmpty);

      h.setSession(_socio);
      await _settle();

      expect(h.navigations, [
        ['/socio/avisos'],
      ]);
    });

    test(
      'el toque inicial con la sesión sin resolver espera a la sesión',
      () async {
        final h = _Harness(session: _checking)..service.initialTap = _historia;

        await h.controller.start();
        await _settle();
        expect(h.navigations, isEmpty);

        h.setSession(_socio);
        await _settle();

        expect(h.navigations, [
          ['/socio/avisos', '/socio/historia/4100'],
        ]);
      },
    );

    test('el destino pendiente se consume una sola vez', () async {
      final h = _Harness(session: _checking);
      await h.controller.start();
      h.service.tapEvents.add(_agenda);
      await _settle();

      h.setSession(_socio);
      await _settle();
      h.setSession(_socio);
      await _settle();

      expect(h.navigations.length, 1);
    });

    test('con dos toques sin sesión queda solo el último', () async {
      final h = _Harness(session: _checking);
      await h.controller.start();
      h.service.tapEvents
        ..add(_agenda)
        ..add(_historia);
      await _settle();

      h.setSession(_socio);
      await _settle();

      expect(h.navigations, [
        ['/socio/avisos', '/socio/historia/4100'],
      ]);
    });
  });

  group('otros roles', () {
    test('el destino pendiente se descarta si se autentica otro rol', () async {
      final h = _Harness(session: _loggedOut);
      await h.controller.start();
      h.service.tapEvents.add(_historia);
      await _settle();

      h.setSession(_medico);
      await _settle();
      expect(h.navigations, isEmpty);

      // Ya descartado: un socio que entre después no lo recibe.
      h.setSession(_socio);
      await _settle();
      expect(h.navigations, isEmpty);
      expect(h.refreshes, 0);
    });

    test('un toque con otro rol ya autenticado se ignora', () async {
      final h = _Harness(session: _medico);
      await h.controller.start();

      h.service.tapEvents.add(_agenda);
      await _settle();
      h.setSession(_socio);
      await _settle();

      expect(h.navigations, isEmpty);
    });
  });

  group('handleTap directo (la acción "Ver" del aviso en primer plano)', () {
    test('con un socio navega al mismo destino', () async {
      final h = _Harness();

      await h.controller.handleTap(_historia);

      expect(h.navigations, [
        ['/socio/avisos', '/socio/historia/4100'],
      ]);
      expect(h.refreshes, 1);
    });
  });
}
