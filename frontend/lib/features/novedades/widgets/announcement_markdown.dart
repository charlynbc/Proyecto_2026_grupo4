import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Comparte el formato entre el detalle y la vista previa de publicación.
class AnnouncementMarkdown extends StatelessWidget {
  const AnnouncementMarkdown({super.key, required this.text, this.onTapLink});

  final String text;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: onTapLink,
      // Las imágenes de una novedad son las que se cargan aparte (galería con
      // enlaces firmados). Una imagen escrita en el texto no se pide a la
      // red, sea cual sea su esquema: se muestra su texto alternativo, o nada
      // si no lo tiene.
      imageBuilder: (uri, title, alt) {
        final text = alt?.trim() ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
        blockSpacing: 16,
      ),
    );
  }
}
