import 'dart:typed_data';

/// Un archivo CSV elegido por el usuario, ya leído en memoria.
class PickedCsvFile {
  const PickedCsvFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  /// Tamaño en bytes.
  int get size => bytes.length;
}
