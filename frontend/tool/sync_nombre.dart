// Reescribe el nombre de la mutualista en los archivos estáticos a partir de
// `kMutualistaName`. Se corre desde frontend/:
//
//   dart run tool/sync_nombre.dart
//
// Reemplaza por posición con expresiones regulares y toca solo el texto
// que cambia, así conserva el formato y el fin de línea (LF o CRLF) de cada
// archivo. Si ya está todo al día no escribe nada.
import 'dart:io';

import 'package:agenda_medica/core/branding.dart';

/// Un lugar donde aparece el nombre. El grupo 2 de [pattern] es el valor
/// actual; los grupos 1 y 3 se conservan tal cual.
class _Target {
  const _Target(this.description, this.pattern, this.escape);

  final String description;
  final RegExp pattern;
  final String Function(String) escape;
}

class _FileRule {
  const _FileRule(this.path, this.targets);

  final String path;
  final List<_Target> targets;
}

String _escapeMarkup(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _escapeJson(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

String _escapeNone(String text) => text;

final _rules = <_FileRule>[
  _FileRule('web/index.html', [
    _Target('<title>', RegExp(r'(<title>)([^<]*)(</title>)'), _escapeMarkup),
    _Target(
      'meta apple-mobile-web-app-title',
      RegExp(
        r'(<meta\s+name="apple-mobile-web-app-title"\s+content=")([^"]*)(")',
      ),
      _escapeMarkup,
    ),
  ]),
  _FileRule('web/manifest.json', [
    // `"name"` con la comilla pegada no coincide con `"short_name"`.
    _Target(
      '"name"',
      RegExp(r'("name"\s*:\s*")((?:[^"\\]|\\.)*)(")'),
      _escapeJson,
    ),
    _Target(
      '"short_name"',
      RegExp(r'("short_name"\s*:\s*")((?:[^"\\]|\\.)*)(")'),
      _escapeJson,
    ),
  ]),
  _FileRule('android/app/src/main/AndroidManifest.xml', [
    _Target(
      'android:label de <application>',
      RegExp(r'(<application\b[^>]*?\sandroid:label=")([^"]*)(")'),
      _escapeMarkup,
    ),
  ]),
  _FileRule('README.md', [
    // Solo la primera línea; `[^\r\n]` deja afuera el CR de un CRLF.
    _Target('primera línea', RegExp(r'^(# )([^\r\n]*)()'), _escapeNone),
  ]),
];

/// `true` si [text] mezcla saltos CRLF con LF sueltos.
bool _hasMixedLineEndings(String text) {
  final crlf = '\r\n'.allMatches(text).length;
  final lf = '\n'.allMatches(text).length;
  return crlf != 0 && crlf != lf;
}

void main() => exit(_sync());

int _sync() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Correr desde frontend/: dart run tool/sync_nombre.dart');
    return 1;
  }

  // Primero se calcula todo en memoria: si algo falla no se escribe nada.
  final pending = <String, String>{};
  for (final rule in _rules) {
    final file = File(rule.path);
    if (!file.existsSync()) {
      stderr.writeln('No existe ${rule.path}.');
      return 1;
    }
    final original = file.readAsStringSync();
    var text = original;
    for (final target in rule.targets) {
      if (!target.pattern.hasMatch(text)) {
        stderr.writeln('No se encontró ${target.description} en ${rule.path}.');
        return 1;
      }
      final value = target.escape(kMutualistaName);
      text = text.replaceFirstMapped(
        target.pattern,
        (m) => '${m.group(1)}$value${m.group(3)}',
      );
    }
    if (_hasMixedLineEndings(text)) {
      stderr.writeln('${rule.path} quedaría con fines de línea mezclados.');
      return 1;
    }
    if (text != original) pending[rule.path] = text;
  }

  if (pending.isEmpty) {
    stdout.writeln('Todo al día: "$kMutualistaName".');
    return 0;
  }
  pending.forEach((path, text) {
    File(path).writeAsStringSync(text);
    stdout.writeln('Actualizado $path');
  });
  return 0;
}
