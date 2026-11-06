import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/csv_file_picker_field.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/user_import.dart';
import '../providers/user_import_controller.dart';
import 'user_routes.dart';

/// Carga masiva de usuarios desde un CSV (RF-32, contrato #54 y #55): se
/// elige el archivo, se previsualiza qué filas sirven y se confirma. Las
/// filas con error se rechazan con su motivo y las válidas se crean.
class UserImportScreen extends ConsumerWidget {
  const UserImportScreen({super.key});

  static const String _instructions =
      'Elegí un archivo CSV con una cuenta por fila y estas columnas, en este '
      'orden: ci, nombre, apellido, fecha_nacimiento, correo, telefono_1, '
      'telefono_2, direccion, rol, especialidades. La fecha va como '
      'aaaa-mm-dd y las especialidades de un médico, separadas por |. '
      'Formato: separador coma o punto y coma, UTF-8, hasta 1 MB y 1000 '
      'filas.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userImportControllerProvider);
    final controller = ref.read(userImportControllerProvider.notifier);
    final stage = state.stage;
    final canPreview =
        state.file != null && !state.isBusy && stage != UserImportStage.noFile;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kUsersPath),
        ),
        title: const Text('Cargar usuarios desde CSV'),
      ),
      body: CenteredContent(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(_instructions, key: Key('import-instructions')),
            const SizedBox(height: 16),
            CsvFilePickerField(
              value: state.file,
              onChanged: controller.setFile,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('import-preview-button'),
              onPressed: canPreview ? controller.preview : null,
              child: const Text('Previsualizar'),
            ),
            if (state.isBusy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (state.errorMessage case final message?) ...[
              const SizedBox(height: 16),
              Text(
                message,
                key: const Key('import-error'),
                style: TextStyle(color: colorScheme.error),
              ),
            ],
            if (state.result case final result?)
              _Result(result: result)
            else if (state.preview case final preview?)
              _Preview(
                preview: preview,
                confirming: stage == UserImportStage.confirming,
                onConfirm: controller.confirm,
              ),
          ],
        ),
      ),
    );
  }
}

/// Totales de la previsualización, las filas con error y "Confirmar".
class _Preview extends StatelessWidget {
  const _Preview({
    required this.preview,
    required this.confirming,
    required this.onConfirm,
  });

  final UserImportPreview preview;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text('Total: ${preview.total}', key: const Key('import-total')),
        Text('Válidas: ${preview.valid}', key: const Key('import-valid')),
        Text('Con error: ${preview.invalid}', key: const Key('import-invalid')),
        _ErrorRows(rows: preview.errors),
        if (preview.valid > 0) ...[
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('import-confirm-button'),
            onPressed: confirming ? null : onConfirm,
            child: const Text('Confirmar importación'),
          ),
        ],
      ],
    );
  }
}

/// Importadas y rechazadas, la nota y los botones para seguir.
class _Result extends ConsumerWidget {
  const _Result({required this.result});

  final UserImportResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Importadas: ${result.imported}',
          key: const Key('import-imported'),
        ),
        Text(
          'Rechazadas: ${result.rejected}',
          key: const Key('import-rejected'),
        ),
        _ErrorRows(rows: result.errors),
        const SizedBox(height: 16),
        const Text(
          'Las cuentas quedan pendientes de primer ingreso. No se envía ningún '
          'correo.',
          key: Key('import-users-note'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('import-back-button'),
              onPressed: () => context.go(kUsersPath),
              child: const Text('Volver a Usuarios'),
            ),
            OutlinedButton(
              key: const Key('import-again-button'),
              onPressed: ref.read(userImportControllerProvider.notifier).reset,
              child: const Text('Cargar otro archivo'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Las filas con error: qué fila es y por qué se rechaza.
class _ErrorRows extends StatelessWidget {
  const _ErrorRows({required this.rows});

  final List<UserImportRow> rows;

  /// "Fila 4: CI 30000033, Sara Lima, SOCIO". Los datos nulos se omiten.
  static String _title(UserImportRow row) {
    final name = [row.firstName, row.lastName].whereType<String>().join(' ');
    final parts = [
      if (row.ci != null) 'CI ${row.ci}',
      if (name.isNotEmpty) name,
      if (row.role != null) row.role!,
    ];
    return parts.isEmpty
        ? 'Fila ${row.number}'
        : 'Fila ${row.number}: ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(row),
                  style: style?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  row.error ?? '',
                  key: Key('import-error-row-${row.number}'),
                  style: style?.copyWith(color: error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
