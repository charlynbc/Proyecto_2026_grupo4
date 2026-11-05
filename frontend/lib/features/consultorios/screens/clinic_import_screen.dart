import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files/csv_file_picker_field.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/clinic_import.dart';
import '../providers/clinic_import_controller.dart';
import 'clinics_screen.dart';

/// Carga masiva de consultorios desde un CSV (RF-34, contrato #56 y #57): se
/// elige el archivo, se previsualiza qué filas sirven y se confirma. Las
/// filas con error se rechazan con su motivo y las válidas se crean.
class ClinicImportScreen extends ConsumerWidget {
  const ClinicImportScreen({super.key});

  static const String _instructions =
      'Elegí un archivo CSV con un consultorio por fila y dos columnas, en '
      'este orden: nombre y ubicacion. Los que ya existen no se modifican. '
      'Formato: separador coma o punto y coma, UTF-8, hasta 1 MB y 1000 '
      'filas.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clinicImportControllerProvider);
    final controller = ref.read(clinicImportControllerProvider.notifier);
    final stage = state.stage;
    final canPreview = state.file != null && !state.isBusy;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kClinicsPath),
        ),
        title: const Text('Cargar consultorios desde CSV'),
      ),
      body: CenteredContent(
        maxWidth: 700,
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
                confirming: stage == ClinicImportStage.confirming,
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

  final ClinicImportPreview preview;
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

/// Importadas y rechazadas, y los botones para seguir.
class _Result extends ConsumerWidget {
  const _Result({required this.result});

  final ClinicImportResult result;

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('import-back-button'),
              onPressed: () => context.go(kClinicsPath),
              child: const Text('Volver a Consultorios'),
            ),
            OutlinedButton(
              key: const Key('import-again-button'),
              onPressed: ref
                  .read(clinicImportControllerProvider.notifier)
                  .reset,
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

  final List<ClinicImportRow> rows;

  /// "Fila 3: Consultorio 7". Un nombre nulo o vacío se omite.
  static String _title(ClinicImportRow row) {
    final name = row.name;
    return name == null || name.isEmpty
        ? 'Fila ${row.number}'
        : 'Fila ${row.number}: $name';
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
