import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/branding.dart';
import 'core/config/app_config.dart';
import 'core/config/app_locale.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/models/user_role.dart';
import 'features/auth/providers/session_provider.dart';
import 'features/notificaciones/providers/push_navigation_provider.dart';
import 'features/notificaciones/providers/push_notification_provider.dart';
import 'features/notificaciones/providers/push_registration_provider.dart';
import 'features/notificaciones/services/android_firebase_init.dart';
import 'features/notificaciones/services/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Rutas sin # en la web (/primer-ingreso?token=X). Fuera de la web no hace
  // nada. El servidor responde el index.html en las rutas de la app.
  usePathUrlStrategy();
  await initializeDateFormatting('es');
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseAnalytics.instance.logAppOpen();
  }
  // Android: Firebase con la configuración de google-services.json. Sin ella
  // (o con USE_FAKES) no se inicializa y la app anda igual, sin avisos push.
  await initializeAndroidFirebase(
    useFakes: AppConfig.useFakes,
    isWeb: kIsWeb,
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
  );
  runApp(const ProviderScope(child: MyApp()));
}

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<ForegroundPushMessage>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    // Atiende el push que abrió la app y los que se toquen en segundo plano.
    unawaited(ref.read(pushNavigationControllerProvider).start());
  }

  /// Un socio inició sesión: muestra los avisos que lleguen con la app abierta
  /// y registra el token del dispositivo (RNF-23). Con `USE_FAKES`, en la web
  /// o fuera de Android el servicio no hace nada.
  Future<void> _onAuthenticated() async {
    final service = ref.read(pushNotificationServiceProvider);
    _pushSubscription?.cancel();
    _pushSubscription = service.foregroundMessages.listen((message) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${message.title}: ${message.body}'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => unawaited(
              ref.read(pushNavigationControllerProvider).handleTap(message.tap),
            ),
          ),
        ),
      );
    });
    await ref.read(pushRegistrationControllerProvider).start();
  }

  /// La sesión terminó: se dejan de escuchar avisos y renovaciones de token.
  /// La baja del token la hace `LogoutButton` antes de cerrar sesión; si la
  /// sesión se cayó por otro camino no hay con qué llamar a la API.
  void _onSessionEnded() {
    _pushSubscription?.cancel();
    _pushSubscription = null;
    ref.read(pushRegistrationControllerProvider).stop();
  }

  @override
  void dispose() {
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    ref.listen<SessionState>(sessionProvider, (previous, next) {
      final becameAuthenticated =
          next.isAuthenticated && !(previous?.isAuthenticated ?? false);
      final lostSession =
          (previous?.isAuthenticated ?? false) && !next.isAuthenticated;
      // El registro de dispositivos (contrato #33) es solo del socio.
      if (becameAuthenticated && next.role == UserRole.socio) {
        unawaited(_onAuthenticated());
      }
      if (lostSession) _onSessionEnded();
      // Un toque de push sin sesión espera a que se autentique un socio.
      ref.read(pushNavigationControllerProvider).onSessionChanged(next);
    });
    return MaterialApp.router(
      title: kMutualistaName,
      locale: kAppLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: appTheme,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
    );
  }
}
