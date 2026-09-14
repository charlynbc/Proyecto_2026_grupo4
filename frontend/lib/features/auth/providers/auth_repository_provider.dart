import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/fake_auth_repository.dart';

/// Punto único de inyección del repositorio de auth. Cuando exista el
/// backend real, este es el único lugar que hay que tocar para enchufar la
/// implementación real (que usará dioProvider) sin tocar la UI.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const FakeAuthRepository();
});
