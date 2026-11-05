import '../../../core/files/picked_csv_file.dart';
import '../models/specialty_import.dart';

/// Carga masiva de especialidades desde un CSV (RF-30, contrato #52 y #53).
///
/// Confirmar recibe el archivo de nuevo: no hay un token de la
/// previsualización, así que quien llama conserva los bytes entre las dos
/// llamadas. Las fallas del archivo (`CSV_INVALIDO`) y de la red llegan como
/// `ApiException` con un mensaje que se puede mostrar.
abstract class SpecialtyImportRepository {
  /// Dice qué filas del archivo sirven y cuáles no, sin crear nada.
  Future<SpecialtyImportPreview> preview(PickedCsvFile file);

  /// Crea una especialidad por cada fila válida y rechaza las demás con su
  /// motivo. Ninguna especialidad existente se modifica.
  Future<SpecialtyImportResult> confirm(PickedCsvFile file);
}
