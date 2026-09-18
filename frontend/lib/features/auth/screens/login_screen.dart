import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/session_provider.dart';
import '../widgets/login_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _kMaxFormWidth = 440.0;

  // Se lee una sola vez, al mostrarse la pantalla: consumeExpired() resetea
  // el flag en el mismo momento en que lo lee, así que guardarlo en el
  // provider y volver a mirarlo en cada build() haría que el aviso
  // desapareciera solo apenas se resetea.
  late final bool _sessionExpired;

  @override
  void initState() {
    super.initState();
    _sessionExpired = ref.read(sessionProvider.notifier).consumeExpired();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/images/logo.svg', height: 225),
                  const SizedBox(height: 24),
                  Text(
                    'Bienvenido al Portal del Socio',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingresá tu cédula de identidad completa, sin puntos ni '
                    'guiones, incluyendo el dígito verificador.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (_sessionExpired) ...[
                    const SizedBox(height: 16),
                    const _SessionExpiredBanner(),
                  ],
                  const SizedBox(height: 24),
                  const LoginForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de que la sesión anterior expiró por seguridad. A diferencia del
/// error de LoginForm (sobre el intento de login actual), este es sobre por
/// qué se llegó a esta pantalla.
class _SessionExpiredBanner extends StatelessWidget {
  const _SessionExpiredBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Tu sesión expiró por seguridad. Volvé a iniciar sesión.',
        style: TextStyle(color: colorScheme.onErrorContainer),
        textAlign: TextAlign.center,
      ),
    );
  }
}
