import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/picked_csv_file.dart';
import '../../../core/network/api_exception.dart';
import '../models/specialty_import.dart';
import 'specialties_provider.dart';
import 'specialty_import_repository_provider.dart';
import 'specialty_search_provider.dart';

/// En qué paso va la carga masiva de especialidades.
enum SpecialtyImportStage {
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
class SpecialtyImportState {
  const SpecialtyImportState({
    this.stage = SpecialtyImportStage.noFile,
    this.file,
    this.preview,
    this.result,
    this.errorMessage,
  });

  final SpecialtyImportStage stage;

  /// El archivo elegido, con sus bytes: confirmar lo manda de nuevo.
  final PickedCsvFile? file;
  final SpecialtyImportPreview? preview;
  final SpecialtyImportResult? result;

  /// El último error (de red o del archivo), listo para mostrar.
  final String? errorMessage;

  bool get isBusy =>
      stage == SpecialtyImportStage.loading ||
      stage == SpecialtyImportStage.confirming;
}

/// Carga masiva de especialidades (RF-30): elegir el archivo, previsualizar y
/// confirmar. Cambiar el archivo reinicia todo. Si se importó al menos una,
/// invalida el catálogo y el listado de especialidades.
class SpecialtyImportController extends Notifier<SpecialtyImportState> {
  @override
  SpecialtyImportState build() => const SpecialtyImportState();

  /// El archivo elegido, o `null` si el campo lo descartó. Reinicia el
  /// resultado, la previsualización y el error. Mientras se envía algo no
  /// hace nada.
  void setFile(PickedCsvFile? file) {
    if (state.isBusy) return;
    state = file == null
        ? const SpecialtyImportState()
        : SpecialtyImportState(stage: SpecialtyImportStage.hasFile, file: file);
  }

  /// Vuelve al principio, sin archivo.
  void reset() {
    if (state.isBusy) return;
    state = const SpecialtyImportState();
  }

  Future<void> preview() async {
    final file = state.file;
    if (file == null || state.isBusy) return;
    state = SpecialtyImportState(
      stage: SpecialtyImportStage.loading,
      file: file,
    );
    try {
      final repository = await ref.read(
        specialtyImportRepositoryProvider.future,
      );
      final preview = await repository.preview(file);
      state = SpecialtyImportState(
        stage: SpecialtyImportStage.previewed,
        file: file,
        preview: preview,
      );
    } catch (e) {
      state = SpecialtyImportState(
        stage: SpecialtyImportStage.hasFile,
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
        state.stage != SpecialtyImportStage.previewed) {
      return;
    }
    // Si se sale de la pantalla mientras se envía, la importación igual
    // termina.
    final link = ref.keepAlive();
    state = SpecialtyImportState(
      stage: SpecialtyImportStage.confirming,
      file: file,
      preview: preview,
    );
    try {
      final repository = await ref.read(
        specialtyImportRepositoryProvider.future,
      );
      final result = await repository.confirm(file);
      if (result.imported > 0) {
        ref.invalidate(specialtiesProvider);
        ref.invalidate(specialtySearchProvider);
      }
      state = SpecialtyImportState(
        stage: SpecialtyImportStage.done,
        file: file,
        result: result,
      );
    } catch (e) {
      state = SpecialtyImportState(
        stage: SpecialtyImportStage.previewed,
        file: file,
        preview: preview,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

final specialtyImportControllerProvider =
    NotifierProvider.autoDispose<
      SpecialtyImportController,
      SpecialtyImportState
    >(SpecialtyImportController.new);
