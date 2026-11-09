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
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
        blockSpacing: 16,
      ),
    );
  }
}
