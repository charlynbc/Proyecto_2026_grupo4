import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/picked_csv_file.dart';
import '../../../core/network/api_exception.dart';
import '../models/clinic_import.dart';
import 'clinic_import_repository_provider.dart';
import 'clinic_search_provider.dart';
import 'clinics_provider.dart';

/// En qué paso va la carga masiva de consultorios.
enum ClinicImportStage {
  /// Todavía no se eligió un archivo.
  noFile,

  /// Hay un archivo elegido, sin previsualizar.
  hasFile,

  /// Se está previsualizando.
  loading,

  /// Se previsualizó: se ven los totales y las filas con error.
  previewed,

  /// Se está confirmando.
  confirming,

  /// Se confirmó: se ve el resultado.
  done,
}

/// Todo lo que muestra la pantalla de la carga masiva.
class ClinicImportState {
  const ClinicImportState({
    this.stage = ClinicImportStage.noFile,
    this.file,
    this.preview,
    this.result,
    this.errorMessage,
  });

  final ClinicImportStage stage;

  /// El archivo elegido, con sus bytes: confirmar lo manda de nuevo.
  final PickedCsvFile? file;
  final ClinicImportPreview? preview;
  final ClinicImportResult? result;

  /// El último error (de red o del archivo), listo para mostrar.
  final String? errorMessage;

  bool get isBusy =>
      stage == ClinicImportStage.loading ||
      stage == ClinicImportStage.confirming;
}

/// Carga masiva de consultorios (RF-34): elegir el archivo, previsualizar y
/// confirmar. Cambiar el archivo reinicia todo. Si se importó al menos uno,
/// invalida lo mismo que el alta individual (el catálogo y el listado), sin
/// tocar los filtros ni el sentido del listado.
class ClinicImportController extends Notifier<ClinicImportState> {
  @override
  ClinicImportState build() => const ClinicImportState();

  /// El archivo elegido, o `null` si el campo lo descartó. Reinicia el
  /// resultado, la previsualización y el error. Mientras se envía algo no
  /// hace nada.
  void setFile(PickedCsvFile? file) {
    if (state.isBusy) return;
    state = file == null
        ? const ClinicImportState()
        : ClinicImportState(stage: ClinicImportStage.hasFile, file: file);
  }

  /// Vuelve al principio, sin archivo.
  void reset() {
    if (state.isBusy) return;
    state = const ClinicImportState();
  }

  Future<void> preview() async {
    final file = state.file;
    if (file == null || state.isBusy) return;
    state = ClinicImportState(stage: ClinicImportStage.loading, file: file);
    try {
      final repository = await ref.read(clinicImportRepositoryProvider.future);
      final preview = await repository.preview(file);
      state = ClinicImportState(
        stage: ClinicImportStage.previewed,
        file: file,
        preview: preview,
      );
    } catch (e) {
      state = ClinicImportState(
        stage: ClinicImportStage.hasFile,
        file: file,
        errorMessage: apiMessageOf(e),
      );
    }
  }

  Future<void> confirm() async {
    final file = state.file;
    final preview = state.preview;
    if (file == null ||
        preview == null ||
        state.stage != ClinicImportStage.previewed) {
      return;
    }
    // Si se sale de la pantalla mientras se envía, la importación igual
    // termina.
    final link = ref.keepAlive();
    state = ClinicImportState(
      stage: ClinicImportStage.confirming,
      file: file,
      preview: preview,
    );
    try {
      final repository = await ref.read(clinicImportRepositoryProvider.future);
      final result = await repository.confirm(file);
      if (result.imported > 0) {
        ref.invalidate(clinicsProvider);
        ref.invalidate(clinicSearchProvider);
      }
      state = ClinicImportState(
        stage: ClinicImportStage.done,
        file: file,
        result: result,
      );
    } catch (e) {
      state = ClinicImportState(
        stage: ClinicImportStage.previewed,
        file: file,
        preview: preview,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

final clinicImportControllerProvider =
    NotifierProvider.autoDispose<ClinicImportController, ClinicImportState>(
      ClinicImportController.new,
    );
