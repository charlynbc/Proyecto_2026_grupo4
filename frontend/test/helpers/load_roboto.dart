import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Roboto (la tipografía por defecto de Material en Android) desde el
/// SDK de Flutter, para que un test mida textos con el ancho real. Sin esto
/// los widget tests usan la fuente Ahem, cuyos caracteres son cuadrados y
/// ensanchan todo. Falla en voz alta si no encuentra los archivos, para no
/// medir con otra fuente sin avisar.
Future<void> loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError(
      'FLUTTER_ROOT no está definido: no se puede cargar Roboto',
    );
  }
  final loader = FontLoader('Roboto');
  for (final name in const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final file = File('$root/bin/cache/artifacts/material_fonts/$name');
    if (!file.existsSync()) {
      throw StateError('Falta ${file.path}: no se puede cargar Roboto');
    }
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}
