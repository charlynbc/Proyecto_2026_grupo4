import 'package:agenda_medica/core/utils/text_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldForSort', () {
    test('saca las tildes de las vocales', () {
      expect(foldForSort('Álvarez'), 'alvarez');
      expect(foldForSort('Méndez'), 'mendez');
      expect(foldForSort('Cardiología'), 'cardiologia');
      expect(foldForSort('Óptica'), 'optica');
      expect(foldForSort('Úrsula'), 'ursula');
    });

    test('también la diéresis y los acentos graves', () {
      expect(foldForSort('Pingüino'), 'pinguino');
      expect(foldForSort('à è ì ò ù'), 'a e i o u');
    });

    test('cubre la tabla completa de caracteres, uno por uno', () {
      expect(
        foldForSort('áàäâãéèëêíìïîóòöôõúùüûñç'),
        'aaaaaeeeeiiiiooooouuuunc',
      );
      expect(
        foldForSort('ÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ'),
        'aaaaaeeeeiiiiooooouuuunc',
      );
    });

    test('la ñ cuenta como n', () {
      expect(foldForSort('Muñoz'), 'munoz');
      expect(foldForSort('NIÑO'), 'nino');
    });

    test('la ç cuenta como c', () {
      expect(foldForSort('Françoise'), 'francoise');
    });

    test('pasa a minúsculas', () {
      expect(foldForSort('SILVA'), 'silva');
      expect(foldForSort('bravo'), 'bravo');
      expect(foldForSort('ÁLVAREZ'), 'alvarez');
    });

    test('saca los espacios de los extremos y respeta los del medio', () {
      expect(foldForSort('  Silva  '), 'silva');
      expect(foldForSort('de la Cruz'), 'de la cruz');
    });

    test('un texto sin cambios queda igual', () {
      expect(foldForSort('silva'), 'silva');
      expect(foldForSort('medicina general'), 'medicina general');
      expect(foldForSort('1234-5'), '1234-5');
    });

    test('un texto vacío o de espacios da vacío', () {
      expect(foldForSort(''), '');
      expect(foldForSort('   '), '');
    });

    test('permite ordenar sin distinguir mayúsculas ni tildes', () {
      final names = ['Silva', 'Álvarez', 'bravo', 'Acosta', 'Méndez'];
      names.sort((a, b) => foldForSort(a).compareTo(foldForSort(b)));
      expect(names, ['Acosta', 'Álvarez', 'bravo', 'Méndez', 'Silva']);
    });
  });
}
