/// Compara textos como los lee una persona: los números valen como cantidad
/// y el resto, en minúsculas. Si uno se acaba antes, va primero.
int compareNatural(String left, String right) {
  final a = _parts(left);
  final b = _parts(right);
  final count = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < count; i++) {
    final compared = _comparePart(a[i], b[i]);
    if (compared != 0) return compared;
  }
  return a.length.compareTo(b.length);
}

/// Ordena una copia. Los textos que comparan igual quedan como llegaron.
List<T> sortedNaturally<T>(List<T> items, String Function(T item) text) {
  final indexed = [
    for (var i = 0; i < items.length; i++) (index: i, item: items[i]),
  ];
  indexed.sort((a, b) {
    final compared = compareNatural(text(a.item), text(b.item));
    if (compared != 0) return compared;
    return a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.item];
}

final _splitter = RegExp(r'\d+|\D+');

typedef _Part = ({bool numeric, String text});

List<_Part> _parts(String value) {
  return [
    for (final match in _splitter.allMatches(value.toLowerCase()))
      (
        numeric: RegExp(r'^\d').hasMatch(match.group(0)!),
        text: match.group(0)!,
      ),
  ];
}

int _comparePart(_Part left, _Part right) {
  if (left.numeric && right.numeric) {
    return BigInt.parse(left.text).compareTo(BigInt.parse(right.text));
  }
  return left.text.compareTo(right.text);
}
