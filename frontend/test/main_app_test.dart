import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/first_login_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_first_login_repository.dart';
import 'package:agenda_medica/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta el `MyApp` de verdad (el de `main.dart`, con su `MaterialApp.router`),
/// con repositories falsos sin latencia, y devuelve el contexto de una pantalla.
Future<BuildContext> _pumpRealApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        employeeAccessAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWith(
          (ref) async => FakeAuthRepository(
            ref.read(sessionProvider.notifier),
            latency: Duration.zero,
          ),
        ),
        firstLoginRepositoryProvider.overrideWith(
          (ref) async => FakeFirstLoginRepository(latency: Duration.zero),
        ),
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return tester.element(find.byType(Scaffold).first);
}

void main() {
  group('idioma de la app (el MaterialApp real)', () {
    testWidgets('la app está en español de Uruguay', (tester) async {
      final context = await _pumpRealApp(tester);

      expect(Localizations.localeOf(context), const Locale('es', 'UY'));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.locale, const Locale('es', 'UY'));
      expect(app.supportedLocales, contains(const Locale('es', 'UY')));
    });

    testWidgets('los textos de Material salen en español', (tester) async {
      final context = await _pumpRealApp(tester);
      final l10n = MaterialLocalizations.of(context);

      expect(l10n.cancelButtonLabel, 'Cancelar');
      expect(l10n.okButtonLabel, 'ACEPTAR');
      expect(l10n.backButtonTooltip, 'Atrás');
      // La variante de Uruguay: no "Seleccionar fecha".
      expect(l10n.datePickerHelpText, 'Selecciona una fecha');
    });

    testWidgets('el calendario empieza la semana el lunes', (tester) async {
      final context = await _pumpRealApp(tester);
      final l10n = MaterialLocalizations.of(context);

      // En MaterialLocalizations, 0 es domingo y 1 es lunes.
      expect(l10n.firstDayOfWeekIndex, 1);
    });

    testWidgets('los nombres de meses y días vienen en español', (
      tester,
    ) async {
      final context = await _pumpRealApp(tester);
      final l10n = MaterialLocalizations.of(context);

      expect(l10n.formatMonthYear(DateTime(2026, 10, 20)), 'octubre de 2026');
      expect(l10n.narrowWeekdays.first, 'D'); // domingo, primero de la lista
      expect(l10n.narrowWeekdays[1], 'L');
    });

    testWidgets('el arranque sigue llevando al login', (tester) async {
      await _pumpRealApp(tester);

      expect(find.text('Ingresar'), findsWidgets);
    });
  });
}
