import 'dart:convert';

import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el título admite 160 caracteres después de recortar espacios', () {
    expect(AnnouncementDraft.validateTitle('a' * 160), isNull);
    expect(AnnouncementDraft.validateTitle('  ${'a' * 160}  '), isNull);
    expect(AnnouncementDraft.validateTitle('a' * 161), isNotNull);
  });

  test('el título de solo espacios es inválido', () {
    expect(AnnouncementDraft.validateTitle('   '), isNotNull);
  });

  test('el resumen admite 300 caracteres y rechaza 301', () {
    expect(AnnouncementDraft.validateSummary('a' * 300), isNull);
    expect(AnnouncementDraft.validateSummary('a' * 301), isNotNull);
  });

  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2k8AAAAASUVORK5CYII=',
  );

  test('un borrador admite cinco imágenes y rechaza seis', () {
    final images = List.generate(
      6,
      (index) => AnnouncementImageUpload(
        name: 'imagen-$index.png',
        bytes: png,
        subtype: 'png',
      ),
    );
    expect(
      AnnouncementDraft(
        title: 'Título',
        images: images.take(5).toList(),
      ).validateContent(),
      isNull,
    );
    expect(
      AnnouncementDraft(title: 'Título', images: images).validateContent(),
      isNotNull,
    );
  });

  test('cada imagen admite 5242880 bytes y rechaza 5242881', () {
    expect(AnnouncementImageUpload.validateSize('imagen.png', 5242880), isNull);
    expect(
      AnnouncementImageUpload.validateSize('imagen.png', 5242881),
      isNotNull,
    );
  });

  test('acepta un PNG con extensión en mayúsculas', () {
    expect(AnnouncementImageUpload.detectSubtype('imagen.PNG', png), 'png');
  });

  test('rechaza una extensión GIF y bytes GIF con extensión permitida', () {
    final gif = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
    );
    expect(AnnouncementImageUpload.detectSubtype('imagen.gif', gif), isNull);
    expect(AnnouncementImageUpload.detectSubtype('imagen.gif', png), isNull);
    expect(AnnouncementImageUpload.detectSubtype('imagen.png', gif), isNull);
  });

  test('el título y el resumen solos no cuentan como contenido', () {
    const draft = AnnouncementDraft(
      title: 'Título',
      summary: 'Resumen',
      text: '   ',
    );
    expect(draft.validateContent(), isNotNull);
  });
}
