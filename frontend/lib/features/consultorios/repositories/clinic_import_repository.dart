import '../../../core/files/picked_csv_file.dart';
import '../models/clinic_import.dart';

/// Carga masiva de consultorios desde un CSV (RF-34, contrato #56 y #57).
///
/// Confirmar recibe el archivo de nuevo: no hay un token de la
/// previsualización, así que quien llama conserva los bytes entre las dos
/// llamadas. Las fallas del archivo (`CSV_INVALIDO`) y de la red llegan como
/// `ApiException` con un mensaje que se puede mostrar.
abstract class ClinicImportRepository {
  /// Dice qué filas del archivo sirven y cuáles no, sin crear nada.
  Future<ClinicImportPreview> preview(PickedCsvFile file);

  /// Crea un consultorio por cada fila válida y rechaza las demás con su
  /// motivo. Ningún consultorio existente se modifica.
  Future<ClinicImportResult> confirm(PickedCsvFile file);
}
