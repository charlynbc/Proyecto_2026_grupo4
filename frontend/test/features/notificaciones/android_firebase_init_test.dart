import 'package:agenda_medica/features/notificaciones/services/android_firebase_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'en Android y sin fakes inicializa Firebase una vez y devuelve true',
    () async {
      var calls = 0;

      final ok = await initializeAndroidFirebase(
        useFakes: false,
        isWeb: false,
        isAndroid: true,
        initializer: () async => calls++,
      );

      expect(ok, isTrue);
      expect(calls, 1);
    },
  );

  test('con USE_FAKES no toca Firebase', () async {
    var calls = 0;

    final ok = await initializeAndroidFirebase(
      useFakes: true,
      isWeb: false,
      isAndroid: true,
      initializer: () async => calls++,
    );

    expect(ok, isFalse);
    expect(calls, 0);
  });

  test('en la web no lo inicializa', () async {
    var calls = 0;

    final ok = await initializeAndroidFirebase(
      useFakes: false,
      isWeb: true,
      isAndroid: true,
      initializer: () async => calls++,
    );

    expect(ok, isFalse);
    expect(calls, 0);
  });

  test('fuera de Android no lo inicializa', () async {
    var calls = 0;

    final ok = await initializeAndroidFirebase(
      useFakes: false,
      isWeb: false,
      isAndroid: false,
      initializer: () async => calls++,
    );

    expect(ok, isFalse);
    expect(calls, 0);
  });

  test(
    'si falta la configuración devuelve false y no propaga el error',
    () async {
      final ok = await initializeAndroidFirebase(
        useFakes: false,
        isWeb: false,
        isAndroid: true,
        initializer: () async => throw StateError('falta google-services.json'),
      );

      expect(ok, isFalse);
    },
  );
}
