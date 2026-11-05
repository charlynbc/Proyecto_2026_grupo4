import 'email_change_repository.dart';

/// Implementación en memoria de [EmailChangeRepository] para
/// `USE_FAKES=true`. No cambia el correo de ninguna cuenta de prueba.
///
/// Vale cualquier token, salvo [expiredToken], [usedToken] y el vacío, que
/// simulan un enlace que ya no sirve (`ENLACE_INVALIDO`).
class FakeEmailChangeRepository implements EmailChangeRepository {
  FakeEmailChangeRepository({this.latency = const Duration(milliseconds: 300)});

  static const String expiredToken = 'vencido';
  static const String usedToken = 'usado';

  final Duration latency;

  @override
  Future<void> confirm({required String token}) async {
    await Future<void>.delayed(latency);
    if (token == expiredToken || token == usedToken || token.isEmpty) {
      throw const InvalidEmailChangeLinkException();
    }
  }
}
