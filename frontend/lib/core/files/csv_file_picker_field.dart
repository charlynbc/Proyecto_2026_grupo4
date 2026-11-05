import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'csv_file_picker.dart';
import 'csv_upload.dart';
import 'picked_csv_file.dart';

/// Campo para elegir un archivo CSV: botón para abrir el selector y, con un
/// archivo elegido, su nombre y su tamaño.
///
/// Rechaza lo que pesa más de 1 MB (avisa con `onChanged(null)` y un texto de
/// error). Si se cancela el selector no cambia nada. La pantalla que lo usa
/// guarda el archivo y se lo devuelve en [value].
class CsvFilePickerField extends ConsumerStatefulWidget {
  const CsvFilePickerField({super.key, required this.onChanged, this.value});

  final ValueChanged<PickedCsvFile?> onChanged;
  final PickedCsvFile? value;

  @override
  ConsumerState<CsvFilePickerField> createState() => _CsvFilePickerFieldState();
}

class _CsvFilePickerFieldState extends ConsumerState<CsvFilePickerField> {
  String? _error;

  Future<void> _pick() async {
    final PickedCsvFile? file;
    try {
      file = await ref.read(csvFilePickerProvider).pick();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo leer el archivo.');
      return;
    }
    if (!mounted || file == null) return;
    if (csvExceedsLimit(file)) {
      setState(() => _error = 'El archivo supera el máximo de 1 MB.');
      widget.onChanged(null);
      return;
    }
    setState(() => _error = null);
    widget.onChanged(file);
  }

  /// "N B" bajo 1024 bytes; si no, KB con coma decimal.
  static String _sizeLabel(int size) {
    if (size < 1024) return '$size B';
    return '${(size / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.value;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('csv-pick-button'),
          onPressed: _pick,
          icon: const Icon(Icons.upload_file),
          label: Text(
            file == null ? 'Elegir archivo CSV' : 'Elegir otro archivo CSV',
          ),
        ),
        if (file != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  file.name,
                  key: const Key('csv-file-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(_sizeLabel(file.size)),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const Key('csv-file-error'),
            style: TextStyle(color: colorScheme.error),
          ),
        ],
      ],
    );
  }
}
