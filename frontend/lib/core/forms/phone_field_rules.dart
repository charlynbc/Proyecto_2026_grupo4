import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Reglas de los campos de teléfono. El contrato no define el formato del
/// teléfono: la regla es una decisión del cliente, pensada para ayudar a quien
/// escribe (la definitiva es del servidor).
///
/// La validez la decide `phone_numbers_parser` (metadatos de libphonenumber).
/// Un número sin `+` se interpreta como uruguayo; uno que empieza con `+` se
/// valida según su propio país. Solo se aceptan celulares y líneas fijas: los
/// números de servicio (0800, 0900, cortos) no sirven para contactar a una
/// persona.

const String kInvalidPhoneMessage =
    'Ese teléfono no parece válido. Revisá el número; si es de otro país, '
    'empezalo con + y el código de país.';

/// Filtro de lo que se puede escribir o pegar en un campo de teléfono:
/// dígitos, espacio, `+`, `-` y paréntesis.
final List<TextInputFormatter> kPhoneInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-()]')),
];

/// En qué estado está un teléfono no vacío mientras se escribe.
enum PhoneStatus {
  /// Celular o línea fija válidos.
  valid,

  /// No es válido todavía, pero puede seguir creciendo hasta serlo.
  incomplete,

  /// No es válido y ya no puede llegar a serlo.
  invalid,
}

/// Los códigos de país tienen a lo sumo 3 dígitos: con 3 o menos, un texto que
/// no se puede interpretar (`+`, `+5`, `00`) todavía puede ser un prefijo.
const int _maxUnparsableDigitsWhileTyping = 3;

const IsoCode _defaultCountry = IsoCode.UY;

int _digitCount(String text) => text.replaceAll(RegExp(r'\D'), '').length;

bool _isValid(PhoneNumber number) =>
    number.isValid(type: PhoneNumberType.mobile) ||
    number.isValid(type: PhoneNumberType.fixedLine);

/// El mayor largo nacional que puede tener un celular o una línea fija del
/// país de [number].
int _maxNationalLength(PhoneNumber number) {
  final lengths = metadataLengthsByIsoCode[number.isoCode]!;
  return [
    ...lengths.mobile,
    ...lengths.fixedLine,
  ].fold(0, (max, length) => length > max ? length : max);
}

/// El largo nacional de [number] sin el prefijo de discado nacional (el `0`
/// de `099...`), que la librería deja puesto si el resto no alcanza.
int _lengthWithoutNationalPrefix(PhoneNumber number) {
  final prefix = metadataByIsoCode[number.isoCode]!.nationalPrefix;
  final match = prefix == null
      ? null
      : RegExp('^(?:$prefix)').firstMatch(number.nsn);
  return number.nsn.length - (match?.end ?? 0);
}

/// El estado del teléfono [text], que no puede estar vacío.
PhoneStatus phoneStatusOf(String text) {
  final PhoneNumber number;
  try {
    number = PhoneNumber.parse(text, callerCountry: _defaultCountry);
  } on PhoneNumberException {
    return _digitCount(text) <= _maxUnparsableDigitsWhileTyping
        ? PhoneStatus.incomplete
        : PhoneStatus.invalid;
  }
  if (_isValid(number)) return PhoneStatus.valid;
  return _lengthWithoutNationalPrefix(number) < _maxNationalLength(number)
      ? PhoneStatus.incomplete
      : PhoneStatus.invalid;
}

/// Si al teléfono [text] todavía le pueden faltar dígitos: mientras se escribe
/// no se marca error en ese caso.
bool isPhoneIncomplete(String text) =>
    phoneStatusOf(text) == PhoneStatus.incomplete;

/// Valida un teléfono opcional: vacío vale; si no, tiene que ser válido.
String? validateOptionalPhone(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return phoneStatusOf(text) == PhoneStatus.valid ? null : kInvalidPhoneMessage;
}
