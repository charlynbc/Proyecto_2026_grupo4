import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Inicializa Firebase en Android con la configuración de `google-services.json`
/// (sin `FirebaseOptions`). No hace nada con `USE_FAKES`, en la web ni fuera de
/// Android. Si falta la configuración devuelve `false` en vez de tirar la app:
/// sin Firebase la app anda igual, solo que sin avisos push.
///
/// [initializer] existe para los tests.
Future<bool> initializeAndroidFirebase({
  required bool useFakes,
  required bool isWeb,
  required bool isAndroid,
  Future<void> Function()? initializer,
}) async {
  if (useFakes || isWeb || !isAndroid) return false;
  try {
    await (initializer ?? _initializeDefaultApp)();
    return true;
  } catch (e) {
    debugPrint('No se pudo inicializar Firebase en Android: $e');
    return false;
  }
}

Future<void> _initializeDefaultApp() async {
  await Firebase.initializeApp();
}
