/// Un texto en minúsculas y sin tildes, para comparar y ordenar sin distinguir
/// mayúsculas ni tildes. La ñ cuenta como n y la ç como c.
String foldForSort(String text) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in text.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}
