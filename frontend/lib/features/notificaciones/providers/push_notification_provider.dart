import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../services/push_notification_service.dart';

/// Punto único de inyección del servicio de notificaciones push. Es async
/// porque `dioProvider` lo es.
final pushNotificationServiceProvider = FutureProvider<PushNotificationService>((
  ref,
) async {
  final dio = await ref.watch(dioProvider.future);
  return PushNotificationService(dio);
});
