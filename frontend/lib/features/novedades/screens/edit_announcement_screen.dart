import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/trimmed_length_limiting_formatter.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../announcement_images.dart';
import '../models/admin_announcement_detail.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_edit.dart';
import '../providers/announcements_provider.dart';
import '../repositories/announcements_repository.dart';
import '../widgets/announcement_markdown_editor.dart';
import '../widgets/announcement_network_image.dart';
import 'new_announcement_screen.dart' show announcementImagePickerProvider;

/// Una imagen de la lista que se está editando: una que la novedad ya tiene
/// (con su `id`) o una nueva que todavía no se subió.
class _ImageEntry {
  _ImageEntry.existing({
    required int this.id,
    required String this.url,
    required this.label,
  }) : upload = null;

  _ImageEntry.added(AnnouncementImageUpload this.upload)
    : id = null,
      url = null,
      label = upload.name;

  final int? id;
  final String? url;
  final AnnouncementImageUpload? upload;

  /// El nombre con que se la nombra en pantalla y en las descripciones de los
  /// botones: no cambia al reordenar.
  final String label;
}

/// Editar el texto y las imágenes de una novedad ya publicada
/// (`PUT /api/admin/anuncios/{id}`). La vigencia no se toca acá: tiene su
/// propia pantalla.
class EditAnnouncementScreen extends ConsumerStatefulWidget {
  const EditAnnouncementScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<EditAnnouncementScreen> createState() =>
      _EditAnnouncementScreenState();
}

class _EditAnnouncementScreenState
    extends ConsumerState<EditAnnouncementScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _text = TextEditingController();
  final _entries = <_ImageEntry>[];

  /// Lo que tenía la novedad al abrir la pantalla. Se carga una sola vez: si
  /// el detalle se vuelve a pedir, no pisa lo que se está escribiendo.
  bool _initialised = false;
  String _originalTitle = '';
  String _originalSummary = '';
  String _originalText = '';
  List<int> _originalImageIds = const [];
  (String, String, String) _lastText = ('', '', '');

  bool _picking = false;
  bool _submitting = false;
  String? _imageError;
  String? _saveError;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _text.dispose();
    super.dispose();
  }

  void _initialise(AdminAnnouncementDetail detail) {
    _initialised = true;
    _originalTitle = detail.title?.trim() ?? '';
    _originalSummary = detail.summary?.trim() ?? '';
    _originalText = detail.text?.trim() ?? '';
    _title.text = _originalTitle;
    _summary.text = _originalSummary;
    _text.text = detail.text ?? '';
    final images = [...detail.images]
      ..sort((a, b) => a.order.compareTo(b.order));
    _originalImageIds = [for (final image in images) image.id];
    _entries.addAll([
      for (final (index, image) in images.indexed)
        _ImageEntry.existing(
          id: image.id,
          url: image.url,
          label: 'Imagen ${index + 1}',
        ),
    ]);
    _lastText = (_title.text, _summary.text, _text.text);
    // Después de cargar los valores: así no cuentan como cambios.
    for (final controller in [_title, _summary, _text]) {
      controller.addListener(_onEdited);
    }
  }

  /// Los mensajes de error se limpian apenas la persona cambia algo del
  /// formulario: es el único lugar donde se limpian (salvo al empezar a
  /// guardar). Si al guardar de nuevo sigue habiendo un problema, vuelven.
  void _clearErrors() {
    _saveError = null;
    _imageError = null;
  }

  /// Los controladores también avisan al mover el cursor o al enfocar: eso no
  /// es un cambio y no limpia el mensaje. Igual se redibuja, porque el botón
  /// Guardar depende del texto.
  void _onEdited() {
    final current = (_title.text, _summary.text, _text.text);
    final changed = current != _lastText;
    _lastText = current;
    setState(() {
      if (changed) _clearErrors();
    });
  }

  bool get _textChanged =>
      _title.text.trim() != _originalTitle ||
      _summary.text.trim() != _originalSummary ||
      _text.text.trim() != _originalText;

  /// Las imágenes se tocan si hay una nueva o si la lista de las que ya tenía
  /// cambió (se quitó alguna o cambió el orden). Si se deshace todo, vuelven a
  /// estar sin tocar y el pedido no lleva la lista.
  bool get _imagesTouched {
    if (_entries.length != _originalImageIds.length) return true;
    for (final (index, entry) in _entries.indexed) {
      if (entry.id == null || entry.id != _originalImageIds[index]) {
        return true;
      }
    }
    return false;
  }

  bool get _dirty => _textChanged || _imagesTouched;

  void _close({bool saved = false}) {
    if (context.canPop()) {
      context.pop(saved);
    } else {
      context.go(UserRole.administrador.announcementsPath);
    }
  }

  Future<void> _addImages() async {
    setState(() {
      _picking = true;
      _imageError = null;
    });
    try {
      final images = await ref.read(announcementImagePickerProvider)(
        _entries.length,
      );
      if (mounted) {
        setState(() {
          _entries.addAll(images.map(_ImageEntry.added));
          _clearErrors();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _imageError = error is ApiException
              ? error.message
              : 'No pudimos leer las imágenes seleccionadas.';
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _move(int from, int to) {
    setState(() {
      _entries.insert(to, _entries.removeAt(from));
      _clearErrors();
    });
  }

  void _remove(int index) {
    setState(() {
      _entries.removeAt(index);
      _clearErrors();
    });
  }

  Future<void> _save() async {
    if (_submitting || _picking || !_dirty) return;
    if (!_form.currentState!.validate()) return;
    final text = _text.text.trim();
    final summary = _summary.text.trim();
    if (text.isEmpty && _entries.isEmpty) {
      setState(() => _saveError = 'Agregá texto o al menos una imagen.');
      return;
    }
    final edit = AnnouncementEdit(
      title: _title.text.trim(),
      summary: summary.isEmpty ? null : summary,
      text: text.isEmpty ? null : text,
      // Sin tocar las imágenes, el pedido no lleva la lista.
      images: _imagesTouched
          ? [
              for (final entry in _entries)
                if (entry.id != null)
                  ExistingImageRef(entry.id!)
                else
                  NewImageRef(entry.upload!),
            ]
          : null,
    );
    setState(() {
      _submitting = true;
      _saveError = null;
    });
    try {
      final repository = await ref.read(announcementsRepositoryProvider.future);
      if (!mounted) return;
      if (ref.read(sessionProvider).role != UserRole.administrador) {
        throw const ApiException(
          'Solo el administrador puede editar novedades.',
        );
      }
      await repository.update(widget.id, edit);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _saveError = apiMessageOf(error);
        });
      }
      return;
    }
    if (!mounted) return;
    invalidateAnnouncementViews(ref);
    ref.invalidate(adminAnnouncementDetailProvider(widget.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Novedad actualizada')));
    _close(saved: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAnnouncementDetailProvider(widget.id));
    final detail = state.asData?.value;
    if (detail != null && !_initialised) _initialise(detail);
    final busy = _submitting || _picking;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: busy ? null : _close,
          ),
          title: const Text('Editar novedad'),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _initialised ? _formBody(context, busy) : _loading(state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading(AsyncValue<AdminAnnouncementDetail> state) {
    final error = state.error;
    if (error == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando novedad…'),
        ],
      );
    }
    if (error is AnnouncementNotFoundException) {
      return const Text(
        'No encontramos esta novedad.',
        style: TextStyle(fontSize: 22),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('No pudimos cargar la novedad.'),
        const SizedBox(height: 8),
        Text(apiMessageOf(error)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => ref.invalidate(
                    adminAnnouncementDetailProvider(widget.id),
                  ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }

  Widget _formBody(BuildContext context, bool busy) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cambiá el texto o las imágenes. La vigencia se cambia desde '
            '"Cambiar vigencia" en la lista de novedades.',
          ),
          const SizedBox(height: 8),
          Text(
            'Si otro administrador guarda esta novedad al mismo tiempo, queda '
            'lo último que se guardó.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('edit-title'),
            controller: _title,
            enabled: !_submitting,
            // Corta al escribir o pegar, con la misma cuenta que
            // `validateTitle` y el servidor (recortado, UTF-16).
            inputFormatters: const [
              TrimmedLengthLimitingFormatter(AnnouncementDraft.maxTitleLength),
            ],
            decoration: InputDecoration(
              labelText: 'Título',
              counter: ValueListenableBuilder(
                valueListenable: _title,
                builder: (context, value, child) => Text(
                  '${value.text.trim().length}/${AnnouncementDraft.maxTitleLength}',
                ),
              ),
            ),
            validator: AnnouncementDraft.validateTitle,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('edit-summary'),
            controller: _summary,
            enabled: !_submitting,
            maxLength: AnnouncementDraft.maxSummaryLength,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Resumen (opcional)'),
            validator: AnnouncementDraft.validateSummary,
          ),
          const SizedBox(height: 12),
          AnnouncementMarkdownEditor(controller: _text, enabled: !_submitting),
          const SizedBox(height: 24),
          Text('Imágenes', style: theme.textTheme.titleMedium),
          const Text(
            'Hasta 5 imágenes JPEG o PNG, de 5 MB y 6000 × 6000 px como máximo '
            'cada una. La primera es la portada.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('edit-add-images'),
              onPressed:
                  busy || _entries.length >= AnnouncementImageUpload.maxCount
                  ? null
                  : _addImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_picking ? 'Cargando imágenes…' : 'Agregar imágenes'),
            ),
          ),
          if (_imageError != null) Text(_imageError!, style: errorStyle),
          for (final (index, entry) in _entries.indexed) ...[
            const SizedBox(height: 8),
            _ImageRow(
              key: ObjectKey(entry),
              entry: entry,
              isCover: index == 0,
              canMoveUp: !busy && index > 0,
              canMoveDown: !busy && index < _entries.length - 1,
              canRemove: !busy,
              onUp: () => _move(index, index - 1),
              onDown: () => _move(index, index + 1),
              onRemove: () => _remove(index),
            ),
          ],
          const SizedBox(height: 24),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _saveError!,
                  key: const Key('edit-error'),
                  style: errorStyle,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('edit-cancel'),
                onPressed: busy ? null : _close,
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('edit-save'),
                onPressed: busy || !_dirty ? null : _save,
                child: Text(_submitting ? 'Guardando…' : 'Guardar cambios'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una imagen de la lista: miniatura, nombre y los botones de subir, bajar y
/// quitar. Los botones van debajo del nombre para que no se corten con el
/// texto grande ni en pantallas angostas, y se usan con teclado o lector de
/// pantalla (no hay que arrastrar).
class _ImageRow extends StatelessWidget {
  const _ImageRow({
    super.key,
    required this.entry,
    required this.isCover,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final _ImageEntry entry;
  final bool isCover;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRemove;

  static const _thumb = 56.0;

  Widget _thumbnail() {
    Widget broken(BuildContext context) =>
        const Center(child: Icon(Icons.broken_image_outlined));
    final upload = entry.upload;
    return SizedBox(
      width: _thumb,
      height: _thumb,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: upload != null
            ? Image.memory(
                upload.bytes,
                fit: BoxFit.cover,
                cacheWidth: 168,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => broken(context),
              )
            : AnnouncementNetworkImage(
                imageId: entry.id,
                url: entry.url!,
                cacheWidth: kAnnouncementImageCacheWidth,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                placeholder: (context) => const ColoredBox(
                  color: Colors.black12,
                  child: SizedBox.expand(),
                ),
                error: broken,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumbnail(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCover)
                        Text(
                          'Portada',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Subir ${entry.label}',
                  onPressed: canMoveUp ? onUp : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Bajar ${entry.label}',
                  onPressed: canMoveDown ? onDown : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: 'Quitar ${entry.label}',
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
