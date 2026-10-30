import '../../../core/network/api_exception.dart';
import '../models/medical_history_entry.dart';
import '../models/medical_history_query.dart';

/// Acceso al listado y al detalle de las atenciones del socio.
abstract class MedicalHistoryRepository {
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query);

  Future<MedicalHistoryEntry> get(int id);
}

/// Atención inexistente o que no pertenece al socio autenticado.
class MedicalHistoryNotFoundException extends ApiException {
  const MedicalHistoryNotFoundException()
    : super(
        'No encontramos esa atención en tu historia clínica. '
        'Volvé al listado y elegí una atención.',
      );
}
