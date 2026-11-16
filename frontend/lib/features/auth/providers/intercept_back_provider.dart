import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Si las pantallas de acceso atienden el botón de atrás del sistema para
/// llevar al ingreso. Solo fuera de la web: en el navegador el atrás sigue
/// siendo el del historial. Existe como provider para poder probar ese caso,
/// porque `kIsWeb` vale siempre `false` en una prueba de widget.
final interceptSystemBackProvider = Provider<bool>((ref) => !kIsWeb);
