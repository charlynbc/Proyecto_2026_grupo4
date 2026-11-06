import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/picked_csv_file.dart';
import '../../../core/network/api_exception.dart';
import '../models/user_import.dart';
import 'user_import_repository_provider.dart';
import 'users_page_provider.dart';

/// En qué paso va la carga masiva de usuarios.
enum UserImportStage {
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
class UserImportState {
  const UserImportState({
    this.stage = UserImportStage.noFile,
    this.file,
    this.preview,
    this.result,
    this.errorMessage,
  });

  final UserImportStage stage;

  /// El archivo elegido, con sus bytes: confirmar lo manda de nuevo.
  final PickedCsvFile? file;
  final UserImportPreview? preview;
  final UserImportResult? result;

  /// El último error (de red o del archivo), listo para mostrar.
  final String? errorMessage;

  bool get isBusy =>
      stage == UserImportStage.loading || stage == UserImportStage.confirming;
}

/// Carga masiva de usuarios (RF-32): elegir el archivo, previsualizar y
/// confirmar. Cambiar el archivo reinicia todo. Al confirmar bien invalida el
/// listado de usuarios.
class UserImportController extends Notifier<UserImportState> {
  @override
  UserImportState build() => const UserImportState();

  /// El archivo elegido, o `null` si el campo lo descartó. Reinicia el
  /// resultado, la previsualización y el error. Mientras se envía algo no
  /// hace nada.
  void setFile(PickedCsvFile? file) {
    if (state.isBusy) return;
    state = file == null
        ? const UserImportState()
        : UserImportState(stage: UserImportStage.hasFile, file: file);
  }

  /// Vuelve al principio, sin archivo.
  void reset() {
    if (state.isBusy) return;
    state = const UserImportState();
  }

  Future<void> preview() async {
    final file = state.file;
    if (file == null || state.isBusy) return;
    state = UserImportState(stage: UserImportStage.loading, file: file);
    try {
      final repository = await ref.read(userImportRepositoryProvider.future);
      final preview = await repository.preview(file);
      state = UserImportState(
        stage: UserImportStage.previewed,
        file: file,
        preview: preview,
      );
    } catch (e) {
      state = UserImportState(
        stage: UserImportStage.hasFile,
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
        state.stage != UserImportStage.previewed) {
      return;
    }
    // Si se sale de la pantalla mientras se envía, la importación igual
    // termina.
    final link = ref.keepAlive();
    state = UserImportState(
      stage: UserImportStage.confirming,
      file: file,
      preview: preview,
    );
    try {
      final repository = await ref.read(userImportRepositoryProvider.future);
      final result = await repository.confirm(file);
      ref.invalidate(usersPageProvider);
      state = UserImportState(
        stage: UserImportStage.done,
        file: file,
        result: result,
      );
    } catch (e) {
      state = UserImportState(
        stage: UserImportStage.previewed,
        file: file,
        preview: preview,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

final userImportControllerProvider =
    NotifierProvider.autoDispose<UserImportController, UserImportState>(
      UserImportController.new,
    );
