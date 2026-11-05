import 'package:flutter/material.dart';

import 'picked_csv_file.dart';

/// Campo para elegir un archivo CSV.
class CsvFilePickerField extends StatelessWidget {
  const CsvFilePickerField({super.key, required this.onChanged, this.value});

  final ValueChanged<PickedCsvFile?> onChanged;
  final PickedCsvFile? value;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
