import '../../historia_clinica/screens/medical_history_screen.dart';
import '../models/push_tap.dart';
import '../screens/notifications_screen.dart';

/// Las rutas que abre un push, en orden: la primera se abre con `go` y la
/// segunda, si hay, se apila encima con `push` (así Atrás vuelve a la primera).
///
/// Un aviso de historia con atención abre Avisos y encima el detalle de esa
/// atención. Cualquier otro tipo, o uno de historia sin `atencionId`, abre solo
/// Avisos.
List<String> destinationForPush(PushTap tap) {
  final atencionId = tap.atencionId;
  if (tap.type == 'HISTORIA_ACTUALIZADA' && atencionId != null) {
    return [kNotificationsPath, '$kMedicalHistoryPath/$atencionId'];
  }
  return [kNotificationsPath];
}
