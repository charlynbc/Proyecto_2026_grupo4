import '../../../core/files/picked_csv_file.dart';
import '../models/user_import.dart';

/// Carga masiva de usuarios desde un CSV (RF-32, contrato #54 y #55).
///
/// Confirmar recibe el archivo de nuevo: no hay un token de la
/// previsualización, así que quien llama conserva los bytes entre las dos
/// llamadas. Las fallas del archivo (`CSV_INVALIDO`) y de la red llegan como
/// `ApiException` con un mensaje que se puede mostrar.
abstract class UserImportRepository {
  /// Dice qué filas del archivo sirven y cuáles no, sin crear nada.
  Future<UserImportPreview> preview(PickedCsvFile file);

  /// Crea una cuenta por cada fila válida (pendiente de primer ingreso, sin
  /// enviar correo) y rechaza las demás con su motivo.
  Future<UserImportResult> confirm(PickedCsvFile file);
}
