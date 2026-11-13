import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'csv_export.dart';
import 'csv_file_saver.dart';
import 'csv_parser.dart';
import 'picked_csv_file.dart';

/// Lo que se le dice a quien baja las filas rechazadas: hay que corregir cada
/// fila según su motivo y, antes de volver a subir el archivo, borrar las
/// columnas que la carga no admite (`error` y las `extra_N`).
const String kImportErrorsRetryHint =
    'Corregí cada fila según el motivo de la columna error. Después '
    'borrá esa columna y las columnas extra_1, extra_2, etc. (si las '
    'hay): el archivo tiene que quedar con exactamente las mismas '
    'columnas que el original.';

/// Botón para bajar un CSV con las filas rechazadas de una carga masiva: el
/// archivo original, solo con las filas con error y una columna `error` con el
/// motivo, más las columnas `extra_N` si alguna fila traía celdas de más. Sin
/// errores no muestra nada.
///
/// Las celdas se leen de [file] (las filas con error del servidor no las
/// traen) con [expectedHeader]. Si algo falla muestra un aviso; si la persona
/// cancela no pasa nada. Mientras guarda queda deshabilitado.
class ImportErrorsDownloadButton extends ConsumerStatefulWidget {
  const ImportErrorsDownloadButton({
    super.key,
    required this.file,
    required this.expectedHeader,
    required this.errorsByRow,
    required this.label,
  });

  final PickedCsvFile file;
  final List<String> expectedHeader;

  /// Número de fila (el del servidor) a motivo del rechazo.
  final Map<int, String> errorsByRow;
  final String label;

  @override
  ConsumerState<ImportErrorsDownloadButton> createState() =>
      _ImportErrorsDownloadButtonState();
}

class _ImportErrorsDownloadButtonState
    extends ConsumerState<ImportErrorsDownloadButton> {
  bool _saving = false;
  bool _failed = false;

  /// El nombre original sin la última extensión, más `-errores.csv`.
  static String _fileName(String original) {
    final dot = original.lastIndexOf('.');
    final base = dot > 0 ? original.substring(0, dot) : original;
    return '$base-errores.csv';
  }

  Future<void> _download() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final table = parseCsv(
        widget.file.bytes,
        expectedHeader: widget.expectedHeader,
      );
      final bytes = buildErrorRowsCsv(
        original: table,
        errorsByRow: widget.errorsByRow,
      );
      await ref
          .read(csvFileSaverProvider)
          .save(_fileName(widget.file.name), bytes);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errorsByRow.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const Key('import-download-button'),
            onPressed: _saving ? null : _download,
            icon: const Icon(Icons.download),
            label: Text(widget.label),
          ),
          const SizedBox(height: 8),
          Text(
            kImportErrorsRetryHint,
            key: const Key('import-download-hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_failed) ...[
            const SizedBox(height: 8),
            Text(
              'No se pudo guardar el archivo.',
              key: const Key('import-download-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
