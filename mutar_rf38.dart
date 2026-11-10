import 'dart:io';
import 'dart:typed_data';

Future<void> main() async {
  final root = File.fromUri(Platform.script).parent;
  final frontend = Directory('${root.path}/frontend');
  final recovery = Directory('${root.path}/.mutar_rf38_recovery');

  if (!await frontend.exists()) {
    stderr.writeln('ERROR: no se encontró la carpeta frontend.');
    exitCode = 1;
    return;
  }

  final files = <String, File>{
    'api': File(
      '${frontend.path}/lib/features/consultorios/repositories/'
      'api_clinic_correction_repository.dart',
    ),
    'fake': File(
      '${frontend.path}/lib/features/consultorios/repositories/'
      'fake_clinic_correction_repository.dart',
    ),
    'screen': File(
      '${frontend.path}/lib/features/consultorios/screens/'
      'edit_clinic_screen.dart',
    ),
    'controller': File(
      '${frontend.path}/lib/features/consultorios/providers/'
      'correct_clinic_controller.dart',
    ),
  };

  for (final entry in files.entries) {
    if (!await entry.value.exists()) {
      stderr.writeln('ERROR: falta ${entry.value.path}');
      exitCode = 1;
      return;
    }
  }

  // Si quedó una ejecución anterior interrumpida, recuperar sus archivos.
  if (await recovery.exists()) {
    stdout.writeln('Se encontró una recuperación pendiente.');
    await _restoreFromRecovery(recovery, files);
    await recovery.delete(recursive: true);
    stdout.writeln('Recuperación anterior completada.\n');
  }

  const testSuite = 'test/features/consultorios';
  const testApi =
      'test/features/consultorios/api_clinic_correction_repository_test.dart';
  const testFake =
      'test/features/consultorios/fake_clinic_correction_repository_test.dart';
  const testScreen = 'test/features/consultorios/edit_clinic_screen_test.dart';

  final mutations = <_Mutation>[
    _Mutation(1, 'Enviar siempre nombre y ubicación.', {
      'api': [
        _Edit(
          "final data = <String, String>{'nombre': ?name, 'ubicacion': ?location};",
          "final data = <String, String>{'nombre': name ?? '', 'ubicacion': location ?? ''};",
        ),
      ],
    }, testApi),

    _Mutation(2, 'Usar PUT en lugar de PATCH.', {
      'api': [
        _Edit(
          'final response = await _dio.patch<Map<String, dynamic>>(',
          'final response = await _dio.put<Map<String, dynamic>>(',
        ),
      ],
    }, testApi),

    _Mutation(3, 'Enviar la solicitud a la ruta de otro consultorio.', {
      'api': [_Edit('ApiRoutes.clinic(id),', 'ApiRoutes.clinic(id + 1),')],
    }, testApi),

    _Mutation(4, 'Considerar duplicado cualquier otro consultorio.', {
      'fake': [
        _Edit(
          'clinic.id != id &&\n'
              '            FakeAdminDatabase.normalize(clinic.name) == normalizedName,',
          'clinic.id != id ||\n'
              '            FakeAdminDatabase.normalize(clinic.name) == normalizedName,',
        ),
      ],
    }, testFake),

    _Mutation(5, 'Comparar nombres sin normalización.', {
      'fake': [
        _Edit(
          'FakeAdminDatabase.normalize(clinic.name) == normalizedName',
          'clinic.name == correctedName',
        ),
      ],
    }, testFake),

    _Mutation(6, 'Permitir una ubicación vacía.', {
      'fake': [
        _Edit(
          'if (correctedLocation!.isEmpty) {',
          'if (correctedLocation!.isEmpty && false) {',
        ),
      ],
    }, testFake),

    _Mutation(7, 'Habilitar Guardar aunque no haya cambios.', {
      'screen': [
        _Edit(
          'onPressed: enabled && hasChanges ? () => _submit(clinic) : null,',
          'onPressed: enabled ? () => _submit(clinic) : null,',
        ),
      ],
    }, testScreen),

    _Mutation(8, 'No invalidar la búsqueda después de corregir.', {
      'controller': [
        _Edit('      ref.invalidate(clinicSearchProvider);\n', ''),
      ],
    }, testScreen),

    _Mutation(9, 'Invalidar los filtros después de guardar.', {
      'controller': [
        _Edit(
          "import 'clinic_search_provider.dart';",
          "import 'clinic_filters_controller.dart';\n"
              "import 'clinic_search_provider.dart';",
        ),
        _Edit(
          '      ref.invalidate(clinicSearchProvider);',
          '      ref.invalidate(clinicSearchProvider);\n'
              '      ref.invalidate(clinicFiltersControllerProvider);',
        ),
      ],
    }, testScreen),

    _Mutation(10, 'No mostrar el error de duplicado junto al nombre.', {
      'screen': [
        _Edit(
          'final duplicateMessage = state.failure == ClinicCorrectionFailure.duplicate\n'
              '        ? state.errorMessage\n'
              '        : null;',
          'final duplicateMessage = state.failure == ClinicCorrectionFailure.duplicate\n'
              '        ? null\n'
              '        : state.errorMessage;',
        ),
      ],
    }, testScreen),

    _Mutation(11, 'Volver al listado también cuando ocurre un error.', {
      'screen': [
        _Edit(
          'if (state.status == SubmitStatus.done) {',
          'if (state.status == SubmitStatus.done || state.status == SubmitStatus.error) {',
        ),
      ],
    }, testScreen),

    _Mutation(12, 'Quitar la protección contra doble envío.', {
      'controller': [_Edit('    if (state.isLoading) return;\n', '')],
      'screen': [
        _Edit(
          'onPressed: enabled && hasChanges ? () => _submit(clinic) : null,',
          'onPressed: hasChanges ? () => _submit(clinic) : null,',
        ),
      ],
    }, testScreen),
  ];

  // Capturar los archivos originales en memoria.
  final originals = <String, Uint8List>{};

  for (final entry in files.entries) {
    originals[entry.key] = await entry.value.readAsBytes();
  }

  // Crear copias persistentes para poder recuperar una ejecución interrumpida.
  await recovery.create();

  for (final entry in files.entries) {
    final backup = File('${recovery.path}/${entry.key}.bin');
    await backup.writeAsBytes(originals[entry.key]!, flush: true);
  }

  var killed = 0;
  var survived = 0;
  var unexpected = 0;
  var restorationSucceeded = false;

  try {
    stdout.writeln('========================================');
    stdout.writeln(' COMPROBANDO TESTS ORIGINALES');
    stdout.writeln('========================================');

    final baseline = await _runTests(frontend, testSuite);
    _printResult(baseline);

    if (baseline.exitCode != 0) {
      stderr.writeln(
        '\nABORTADO: los tests originales no pasan. '
        'No se ejecutarán las mutaciones.',
      );
      exitCode = 1;
      return;
    }

    stdout.writeln('\nTests originales correctos.');
    stdout.writeln('Comenzando las 12 mutaciones.\n');

    for (final mutation in mutations) {
      stdout.writeln('----------------------------------------');
      stdout.writeln('MUTACIÓN ${mutation.number}/12: ${mutation.description}');
      stdout.writeln('----------------------------------------');

      try {
        // Aplicar los cambios correspondientes a esta mutación.
        for (final entry in mutation.edits.entries) {
          final file = files[entry.key]!;
          var content = await file.readAsString();

          for (final edit in entry.value) {
            content = _replaceExactlyOnce(
              content,
              edit.before,
              edit.after,
              file.path,
            );
          }

          await file.writeAsString(content, flush: true);
        }

        // Ejecutar los tests específicos de esta mutación.
        final result = await _runTests(frontend, mutation.testPath);
        _printResult(result);

        if (result.exitCode == 0) {
          survived++;
          stdout.writeln(
            'RESULTADO: SOBREVIVIÓ. Los tests no detectaron la mutación.',
          );
        } else {
          killed++;
          stdout.writeln(
            'RESULTADO: DETECTADA. El proceso de tests terminó con error.',
          );
        }
      } catch (error, stack) {
        unexpected++;
        stderr.writeln('ERROR INESPERADO: $error');
        stderr.writeln(stack);
      } finally {
        // Restaurar los archivos después de cada mutación.
        await _restoreOriginals(files, originals);

        final restored = await _matchesOriginals(files, originals);

        if (!restored) {
          throw StateError(
            'No se pudo verificar la restauración de la mutación '
            '${mutation.number}.',
          );
        }

        stdout.writeln('Restauración verificada.\n');
      }
    }
  } finally {
    // Restauración global adicional por seguridad.
    await _restoreOriginals(files, originals);
    restorationSucceeded = await _matchesOriginals(files, originals);

    if (restorationSucceeded) {
      await recovery.delete(recursive: true);
    } else {
      stderr.writeln(
        'ATENCIÓN: no se pudo verificar la restauración. '
        'Las copias siguen en ${recovery.path}',
      );
    }
  }

  if (!restorationSucceeded) {
    stderr.writeln('La restauración final falló.');
    exitCode = 1;
    return;
  }

  stdout.writeln('\n========================================');
  stdout.writeln(' VERIFICACIÓN FINAL');
  stdout.writeln('========================================');

  final finalTests = await _runTests(frontend, testSuite);
  _printResult(finalTests);

  stdout.writeln('\n========================================');
  stdout.writeln(' RESUMEN');
  stdout.writeln('========================================');
  stdout.writeln('Mutaciones detectadas: $killed/12');
  stdout.writeln('Mutaciones sobrevivientes: $survived/12');
  stdout.writeln('Errores inesperados: $unexpected/12');
  stdout.writeln('Archivos restaurados: ${restorationSucceeded ? "SÍ" : "NO"}');

  if (finalTests.exitCode != 0 || survived > 0 || unexpected > 0) {
    exitCode = 1;
  } else {
    stdout.writeln('\nProceso completado correctamente.');
  }
}

/// Reemplaza un fragmento que debe aparecer exactamente una vez.
/// Conserva el estilo de finales de línea del archivo (LF o CRLF).
String _replaceExactlyOnce(
  String source,
  String before,
  String after,
  String filePath,
) {
  final lineEnding = source.contains('\r\n') ? '\r\n' : '\n';
  final expected = before.replaceAll('\n', lineEnding);
  final replacement = after.replaceAll('\n', lineEnding);

  final first = source.indexOf(expected);

  if (first == -1) {
    throw StateError(
      'No se encontró el fragmento esperado en $filePath:\n$before',
    );
  }

  final second = source.indexOf(expected, first + expected.length);

  if (second != -1) {
    throw StateError(
      'El fragmento aparece más de una vez en $filePath:\n$before',
    );
  }

  return source.replaceRange(first, first + expected.length, replacement);
}

Future<ProcessResult> _runTests(Directory frontend, String testPath) async {
  return Process.run(
    'flutter',
    ['test', testPath],
    workingDirectory: frontend.path,
    runInShell: Platform.isWindows,
  );
}

void _printResult(ProcessResult result) {
  final stdoutText = result.stdout?.toString() ?? '';
  final stderrText = result.stderr?.toString() ?? '';

  if (stdoutText.isNotEmpty) {
    stdout.write(stdoutText);
  }

  if (stderrText.isNotEmpty) {
    stderr.write(stderrText);
  }

  if (result.exitCode != 0) {
    stdout.writeln('Código de salida: ${result.exitCode}');
  }
}

Future<void> _restoreOriginals(
  Map<String, File> files,
  Map<String, Uint8List> originals,
) async {
  for (final entry in files.entries) {
    await entry.value.writeAsBytes(originals[entry.key]!, flush: true);
  }
}

Future<bool> _matchesOriginals(
  Map<String, File> files,
  Map<String, Uint8List> originals,
) async {
  for (final entry in files.entries) {
    final current = await entry.value.readAsBytes();
    final original = originals[entry.key]!;

    if (current.length != original.length) {
      return false;
    }

    for (var i = 0; i < current.length; i++) {
      if (current[i] != original[i]) {
        return false;
      }
    }
  }

  return true;
}

Future<void> _restoreFromRecovery(
  Directory recovery,
  Map<String, File> files,
) async {
  for (final entry in files.entries) {
    final backup = File('${recovery.path}/${entry.key}.bin');

    if (await backup.exists()) {
      await entry.value.writeAsBytes(await backup.readAsBytes(), flush: true);
    }
  }
}

class _Edit {
  const _Edit(this.before, this.after);

  final String before;
  final String after;
}

class _Mutation {
  const _Mutation(this.number, this.description, this.edits, this.testPath);

  final int number;
  final String description;
  final Map<String, List<_Edit>> edits;
  final String testPath;
}
