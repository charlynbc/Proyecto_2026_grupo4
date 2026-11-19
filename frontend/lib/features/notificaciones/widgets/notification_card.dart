import 'package:flutter/material.dart';

import '../../../core/utils/ui_date_time.dart';
import '../models/app_notification.dart';

/// Un aviso del socio: ícono según el tipo, título, contenido y fecha y hora
/// de Uruguay. Al tocarlo se llama [onTap]; la navegación es de quien lo usa.
/// Sin [onTap] (un aviso que no lleva a ningún lado) no se puede tocar y no
/// muestra la flecha de abrir.
class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = notification;
    final icon = notificationIconFor(value.type);
    final date = formatUiDateTime(value.createdAt);
    return Card(
      // Un lector de pantalla lee cada aviso como una sola etiqueta (título,
      // contenido y fecha con hora), sin leer aparte el ícono ni la flecha.
      child: Semantics(
        label: '${value.title}. ${_sentence(value.content)} $date',
        button: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        child: ListTile(
          key: Key('notification-${value.id}'),
          // Decorativo: el título que lee el lector de pantalla es el del
          // servidor, el cliente no arma uno por tipo.
          leading: Icon(icon, key: Key('notification-icon-${value.id}')),
          title: Text(value.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.content, key: Key('notification-content-${value.id}')),
              const SizedBox(height: 4),
              Text(date, key: Key('notification-date-${value.id}')),
            ],
          ),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// El texto terminado en punto (o en otro cierre de oración), para que la
/// etiqueta que lee un lector de pantalla no junte la oración con la fecha.
String _sentence(String text) {
  final trimmed = text.trimRight();
  return RegExp(r'[.!?]$').hasMatch(trimmed) ? trimmed : '$trimmed.';
}

/// El ícono de cada tipo de aviso. Un tipo que el cliente no conoce usa un
/// ícono genérico.
IconData notificationIconFor(String type) => switch (type) {
  'AGENDA' => Icons.event_available,
  'CANCELACION' => Icons.event_busy,
  'SUSPENSION' => Icons.pause_circle_outline,
  'HISTORIA_ACTUALIZADA' => Icons.medical_information_outlined,
  'RECORDATORIO' => Icons.alarm,
  _ => Icons.notifications_none,
};
