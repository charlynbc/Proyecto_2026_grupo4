import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../models/access_type.dart';
import '../providers/session_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/login_form.dart';

/// Login con dos accesos, Socio y Empleado, según los mockups (diseño 6.1.1 y
/// 6.2.1). El de empleados existe solo en la web (RNF-02): en Android la
/// pantalla muestra únicamente el acceso de socios, sin selector.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.access = AccessType.socio,
    this.accountActivated = false,
  });

  /// Acceso pedido por la ruta (`?acceso=`).
  final AccessType access;

  /// Se llegó desde la activación de la cuenta: se muestra el aviso de éxito.
  final bool accountActivated;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
    final employeeAvailable = ref.watch(employeeAccessAvailableProvider);
    final access = employeeAvailable ? widget.access : AccessType.socio;
    final isMember = access == AccessType.socio;

    return AuthScaffold(
      subtitle: isMember ? 'Acceso para socios' : 'Acceso para empleados',
      children: [
        if (_sessionExpired) ...[
          const SessionEndedNotice(),
          const SizedBox(height: 16),
        ],
        if (widget.accountActivated) ...[
          const AuthNotice(
            title: 'Tu cuenta quedó activa',
            messages: ['Ingresá con tu cédula y la contraseña que elegiste.'],
          ),
          const SizedBox(height: 16),
        ],
        // La clave por acceso descarta lo escrito al cambiar de acceso.
        LoginForm(key: ValueKey(access), access: access),
        const Divider(height: 32),
        if (!employeeAvailable)
          Text(
            'Si sos funcionario, médico o administrador, ingresá desde la '
            'versión web: el acceso de empleados no está en la aplicación '
            'Android.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          )
        else
          Column(
            children: [
              Text(
                isMember
                    ? '¿Es funcionario, médico o administrador?'
                    : '¿Es socio?',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => context.go(
                  isMember
                      ? '/login?acceso=${AccessType.empleado.queryValue}'
                      : '/login',
                ),
                child: Text(
                  isMember
                      ? 'Ingresar por el acceso de empleados'
                      : 'Ingresar por el acceso de socios',
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Aviso de que la sesión anterior terminó. El servidor responde lo mismo si
/// la sesión venció, se cerró desde otro lugar o la cuenta se inactivó, así
/// que el texto cubre las tres sin afirmar ninguna.
class SessionEndedNotice extends StatelessWidget {
  const SessionEndedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthNotice(
      title: 'Tu sesión se cerró',
      messages: [
        'Por seguridad, la sesión se cierra sola después de un tiempo, o si '
            'se cerró desde otro dispositivo, o si tu cuenta dejó de estar '
            'habilitada. Así nadie más puede ver ni cambiar tus datos.',
        'Ingresá de nuevo con tu cédula y tu contraseña. Si no podés '
            'ingresar, comunicate con la institución.',
      ],
    );
  }
}
