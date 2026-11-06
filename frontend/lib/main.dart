import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';

import 'core/branding.dart';
import 'core/config/app_locale.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/models/user_role.dart';
import 'features/auth/providers/session_provider.dart';
import 'features/notificaciones/providers/push_notification_provider.dart';
import 'features/notificaciones/services/push_notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseAnalytics.instance.logAppOpen();
  }
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

  Future<void> _onAuthenticated() async {
    final service = await ref.read(pushNotificationServiceProvider.future);
    final registered = await service.register();
    if (!registered || !mounted) return;
    _pushSubscription?.cancel();
    _pushSubscription = service.foregroundMessages.listen((message) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('${message.title}: ${message.body}')),
      );
    });
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
      // El registro de dispositivos (contrato #33) es solo del socio.
      if (becameAuthenticated && next.role == UserRole.socio) {
        _onAuthenticated();
      }
    });
    return MaterialApp.router(
      title: kMutualistaName,
      locale: kAppLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: appTheme,
      routerConfig: router,
    );
  }
}
