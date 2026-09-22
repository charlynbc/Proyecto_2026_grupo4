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
    // Leer y escribir se separan: modificar sessionProvider acá (durante
    // build del árbol) tira "Tried to modify a provider while the widget
    // tree was building". La lectura es segura en initState; el reset del
    // flag se difiere a después del primer frame.
    _sessionExpired = ref.read(sessionProvider).expired;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sessionProvider.notifier).consumeExpired();
    });
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu sesión se cerró',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por seguridad, la sesión se cierra sola después de un '
                  'tiempo. Esto protege tus datos si dejás el portal '
                  'abierto en una computadora o un celular que usan otras '
                  'personas. De esta forma, nadie más puede ver ni cambiar '
                  'tus turnos.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresá de nuevo con tu cédula y tu contraseña. Si '
                  'estabas reservando un turno, fijate en Mis reservas si '
                  'quedó confirmado.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
