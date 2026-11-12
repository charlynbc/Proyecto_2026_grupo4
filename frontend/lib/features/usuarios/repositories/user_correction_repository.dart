import '../../../core/network/api_exception.dart';
import '../models/account_detail.dart';
import '../models/new_user.dart' show formatApiDate;

/// Leer y corregir los datos de una cuenta (contrato, filas 68 y 58, RF-38).
/// Es un repositorio aparte para no tocar [UserRepository] ni sus dobles.
abstract class UserCorrectionRepository {
  /// El detalle de la cuenta [id] (`GET /api/usuarios/{id}`).
  Future<AccountDetail> fetch(int id);

  /// Corrige la cuenta [id] (`PATCH /api/usuarios/{id}`): manda solo lo que
  /// trae [changes] y devuelve la cuenta como quedó.
  Future<AccountDetail> correct(int id, AccountCorrection changes);
}

/// El cambio de un campo de texto que se puede borrar. En [AccountCorrection]
/// un `null` es "no tocar"; para borrar el dato hay que pasar
/// [TextChange.clear], que viaja como `null` explícito.
class TextChange {
  const TextChange.set(String this.value);

  const TextChange.clear() : value = null;

  /// El texto nuevo, o `null` para borrar el dato.
  final String? value;
}

/// Los campos que se corrigen de una cuenta. Todos son opcionales: lo que
/// queda en `null` no se manda y el servidor no lo toca.
class AccountCorrection {
  const AccountCorrection({
    this.ci,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.email,
    this.phone1,
    this.phone2,
    this.address,
    this.specialtyIds,
  });

  final String? ci;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? email;
  final String? phone1;

  /// Teléfono 2: [TextChange.clear] lo borra; `null` no lo toca.
  final TextChange? phone2;

  /// Dirección: [TextChange.clear] la borra (el servidor solo lo permite si
  /// la cuenta no completó el primer ingreso); `null` no la toca.
  final TextChange? address;

  /// Solo médicos: el conjunto completo, que reemplaza al anterior.
  final List<int>? specialtyIds;

  bool get isEmpty => toJson().isEmpty;

  Map<String, Object?> toJson() => {
    'ci': ?ci,
    'nombre': ?firstName,
    'apellido': ?lastName,
    if (birthDate != null) 'fechaNacimiento': formatApiDate(birthDate!),
    'correo': ?email,
    'telefono1': ?phone1,
    if (phone2 != null) 'telefono2': phone2!.value,
    if (address != null) 'direccion': address!.value,
    'especialidadIds': ?specialtyIds,
  };
}

/// Por qué no se pudo leer o corregir la cuenta.
enum UserCorrectionFailure {
  notFound,
  invalidCi,
  ciInUse,
  specialtyInUse,
  validation,
  other,
}

/// Una lectura o corrección rechazada. El [message] es el del servidor, que
/// es seguro para mostrar.
class UserCorrectionException extends ApiException {
  const UserCorrectionException(this.failure, [super.message]);

  final UserCorrectionFailure failure;
}
