import 'package:agenda_medica/features/notificaciones/providers/push_navigation_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Un router que anota cada llamada y cuántos cuadros se dibujaron entre `go`
/// y `push`. No navega: solo sirve para comprobar el orden.
class _RecordingRouter implements GoRouter {
  final List<String> calls = [];
  int framesSinceGo = 0;
  int? framesBeforePush;

  @override
  void go(String location, {Object? extra}) {
    calls.add('go:$location');
    framesSinceGo = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => framesSinceGo++);
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) async {
    calls.add('push:$location');
    framesBeforePush = framesSinceGo;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('con dos rutas hace go a la primera, espera un cuadro y apila la '
      'segunda con push', (tester) async {
    final router = _RecordingRouter();

    final done = openPushRoutes(router, [
      '/socio/avisos',
      '/socio/historia/4100',
    ]);
    await tester.pump();
    await done;

    expect(router.calls, ['go:/socio/avisos', 'push:/socio/historia/4100']);
    expect(
      router.framesBeforePush,
      1,
      reason: 'el push debe esperar a que termine el cuadro que sigue al go',
    );
  });

  testWidgets('con una sola ruta hace solo go', (tester) async {
    final router = _RecordingRouter();

    await openPushRoutes(router, ['/socio/avisos']);

    expect(router.calls, ['go:/socio/avisos']);
  });
}
