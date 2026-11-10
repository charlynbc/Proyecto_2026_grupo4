/// Campos editables del PATCH de la cuenta propia (contrato, fila 47).
class AccountChanges {
  const AccountChanges({this.address, this.phone1, this.phone2, this.email});

  final String? address;
  final String? phone1;

  /// Sin registro conserva el teléfono. Un registro con valor nulo lo borra.
  final ({String? value})? phone2;

  final String? email;

  bool get isEmpty =>
      address == null && phone1 == null && phone2 == null && email == null;

  Map<String, Object?> toJson() => {
    if (address case final value?) 'direccion': value.trim(),
    if (phone1 case final value?) 'telefono1': value.trim(),
    if (phone2 case (:final value)) 'telefono2': value?.trim(),
    if (email case final value?) 'correo': value.trim(),
  };
}
