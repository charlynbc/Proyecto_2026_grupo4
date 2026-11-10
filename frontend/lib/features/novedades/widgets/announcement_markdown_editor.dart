import 'package:flutter/material.dart';

import 'announcement_markdown.dart';

class AnnouncementMarkdownEditor extends StatefulWidget {
  const AnnouncementMarkdownEditor({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  State<AnnouncementMarkdownEditor> createState() =>
      _AnnouncementMarkdownEditorState();
}

class _AnnouncementMarkdownEditorState
    extends State<AnnouncementMarkdownEditor> {
  final _focus = FocusNode();
  bool _preview = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  TextSelection get _selection {
    final controller = widget.controller;
    final selection = controller.selection;
    return selection.isValid && selection.end <= controller.text.length
        ? selection
        : TextSelection.collapsed(offset: controller.text.length);
  }

  void _replace(
    int start,
    int end,
    String replacement,
    TextSelection selection,
  ) {
    widget.controller.value = TextEditingValue(
      text: widget.controller.text.replaceRange(start, end, replacement),
      selection: selection,
    );
    _focus.requestFocus();
  }

  void _wrap(String prefix, String suffix, {bool link = false}) {
    final selection = _selection;
    final selected = selection.textInside(widget.controller.text);
    final text = selected.isEmpty ? 'texto' : selected;
    final start = selection.start + prefix.length;
    final inner = link ? start + text.length + 2 : start;
    _replace(
      selection.start,
      selection.end,
      '$prefix$text$suffix',
      TextSelection(
        baseOffset: inner,
        extentOffset: inner + (link ? 'https://'.length : text.length),
      ),
    );
  }

  void _prefixLines(String prefix, String placeholder) {
    final selection = _selection;
    final text = widget.controller.text;
    final start = text.substring(0, selection.start).lastIndexOf('\n') + 1;
    final endOfLine = text.indexOf('\n', selection.end);
    final end = endOfLine < 0 ? text.length : endOfLine;
    final lines = text.substring(start, end);
    final replacement = lines.isEmpty
        ? '$prefix$placeholder'
        : lines
              .split('\n')
              .map((line) => line.isEmpty ? line : '$prefix$line')
              .join('\n');
    _replace(
      start,
      end,
      replacement,
      lines.isEmpty
          ? TextSelection(
              baseOffset: start + prefix.length,
              extentOffset: start + replacement.length,
            )
          : TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!_preview) ...[
              _format(Icons.format_bold, 'Negrita', () => _wrap('**', '**')),
              _format(Icons.format_italic, 'Cursiva', () => _wrap('*', '*')),
              _format(
                Icons.title,
                'Subtítulo',
                () => _prefixLines('## ', 'Subtítulo'),
              ),
              _format(
                Icons.format_list_bulleted,
                'Lista',
                () => _prefixLines('- ', 'Elemento'),
              ),
              _format(
                Icons.link,
                'Enlace',
                () => _wrap('[', '](https://)', link: true),
              ),
            ],
            TextButton.icon(
              onPressed: widget.enabled
                  ? () => setState(() => _preview = !_preview)
                  : null,
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
              label: Text(_preview ? 'Editar texto' : 'Vista previa'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_preview)
          Card.outlined(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: text.isEmpty
                  ? const Text('Todavía no agregaste texto.')
                  : AnnouncementMarkdown(text: text),
            ),
          )
        else
          TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Texto de la novedad',
              alignLabelWithHint: true,
              helperText:
                  'Podés escribir en Markdown o usar los botones de formato.',
              helperMaxLines: 2,
            ),
          ),
      ],
    );
  }

  Widget _format(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
        tooltip: tooltip,
        onPressed: widget.enabled ? action : null,
        icon: Icon(icon),
      );
}
