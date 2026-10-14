import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuración de arranque. Se define al compilar o correr con
/// `--dart-define`, y es el único lugar donde se leen esas variables.
///
/// - `USE_FAKES=true`: los repositories usan datos en memoria en lugar de la
///   API (por defecto `false`).
/// - `API_BASE_URL`: dirección del backend (por defecto el backend local).
class AppConfig {
  AppConfig._();

  static const bool useFakes = bool.fromEnvironment('USE_FAKES');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}

/// Único lugar de decisión entre repositories falsos y reales. Los providers
/// de repository lo leen; los tests lo sobreescriben.
final useFakesProvider = Provider<bool>((ref) => AppConfig.useFakes);
