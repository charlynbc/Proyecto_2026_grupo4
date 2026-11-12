import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Manda la app al fondo y la vuelve a traer, recorriendo los estados en el
/// orden en que los emite el sistema (el framework rechaza saltar de `hidden`
/// a `resumed`).
void backgroundAndReturn(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}
