import 'package:agenda_medica/core/forms/trimmed_length_limiting_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _formatter = TrimmedLengthLimitingFormatter(160);

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

TextEditingValue _format(String text) =>
    _formatter.formatEditUpdate(_value(''), _value(text));

/// Ninguna mitad de un par sustituto queda sola.
bool _hasNoBrokenPair(String text) {
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    if (isHigh && (i + 1 >= units.length || !_isLow(units[i + 1]))) {
      return false;
    }
    if (isLow && (i == 0 || !_isHigh(units[i - 1]))) return false;
  }
  return true;
}

bool _isHigh(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLow(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

void main() {
  const emoji = '\u{1F600}';

  test('161 "a" tecleadas de a una quedan en 160', () {
    var current = _value('');
    for (var i = 0; i < 161; i++) {
      current = _formatter.formatEditUpdate(
        current,
        _value('${current.text}a'),
      );
    }

    expect(current.text, 'a' * 160);
  });

  test('pegar 300 "a" deja 160', () {
    expect(_format('a' * 300).text, 'a' * 160);
  });

  test('161 "á" quedan en 160', () {
    expect(_format('á' * 161).text, 'á' * 160);
  });

  test('100 emojis (200 unidades) quedan en 80 emojis, sin pares partidos', () {
    final result = _format(emoji * 100).text;

    expect(result, emoji * 80);
    expect(result.length, 160);
    expect(_hasNoBrokenPair(result), isTrue);
  });

  test('159 "a" y un emoji dejan 159 "a": el emoji se descarta entero', () {
    final result = _format('${'a' * 159}$emoji').text;

    expect(result, 'a' * 159);
    expect(_hasNoBrokenPair(result), isTrue);
  });

  test('los espacios de la izquierda no cuentan y se conservan', () {
    final left = ' ' * 5;

    expect(_format('$left${'a' * 156}').text, '$left${'a' * 156}');
    expect(_format('$left${'a' * 160}').text, '$left${'a' * 160}');
    expect(_format('$left${'a' * 161}').text, '$left${'a' * 160}');
  });

  test('160 "a" con 3 espacios finales se aceptan sin cambios', () {
    final text = '${'a' * 160}   ';

    final result = _format(text);

    expect(result.text, text);
    expect(result, _value(text));
  });

  test('los espacios finales que quedan al cortar se descartan', () {
    // 159 "a", un espacio y 5 "b": recortado mide 165.
    final result = _format('${'a' * 159} ${'b' * 5}').text;

    expect(result, 'a' * 159);
  });

  test('con corte, la selección queda colapsada al final y en rango', () {
    final result = _formatter.formatEditUpdate(
      _value('a' * 160),
      TextEditingValue(
        text: 'a' * 300,
        selection: const TextSelection(baseOffset: 10, extentOffset: 300),
      ),
    );

    expect(result.text.length, 160);
    expect(result.selection, const TextSelection.collapsed(offset: 160));
  });

  test('con el corte de un emoji, la selección no se pasa del texto', () {
    final result = _format('${'a' * 159}$emoji');

    expect(result.selection.isCollapsed, isTrue);
    expect(result.selection.end, result.text.length);
  });
}
