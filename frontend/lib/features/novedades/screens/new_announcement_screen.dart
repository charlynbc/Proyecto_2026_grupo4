import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../models/announcement_draft.dart';
import '../providers/announcements_provider.dart';
import '../widgets/announcement_markdown_editor.dart';

final announcementImagePickerProvider =
    Provider<Future<List<AnnouncementImageUpload>> Function(int)>(
      (ref) => _pickImages,
    );

Future<List<AnnouncementImageUpload>> _pickImages(int attachedCount) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: AnnouncementImageUpload.allowedExtensions,
  );
  final countError = AnnouncementImageUpload.validateCount(
    attachedCount + files.length,
  );
  if (countError != null) throw ApiException(countError);
  final images = <AnnouncementImageUpload>[];
  for (final file in files) {
    final sizeError = AnnouncementImageUpload.validateSize(
      file.name,
      await file.length() ?? 0,
    );
    if (sizeError != null) throw ApiException(sizeError);
    final bytes = await file.readAsBytes();
    final bytesError = AnnouncementImageUpload.validateSize(
      file.name,
      bytes.length,
    );
    if (bytesError != null) throw ApiException(bytesError);
    final subtype = AnnouncementImageUpload.detectSubtype(file.name, bytes);
    if (subtype == null) {
      throw ApiException(AnnouncementImageUpload.invalidTypeMessage(file.name));
    }
    images.add(
      AnnouncementImageUpload(name: file.name, bytes: bytes, subtype: subtype),
    );
  }
  return images;
}

class NewAnnouncementScreen extends ConsumerStatefulWidget {
  const NewAnnouncementScreen({super.key});

  @override
  ConsumerState<NewAnnouncementScreen> createState() =>
      _NewAnnouncementScreenState();
}

class _NewAnnouncementScreenState extends ConsumerState<NewAnnouncementScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _text = TextEditingController();
  final _images = <AnnouncementImageUpload>[];
  bool _picking = false;
  bool _submitting = false;
  String? _imageError;
  String? _publishError;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _text.dispose();
    super.dispose();
  }

  void _close({bool published = false}) {
    if (context.canPop()) {
      context.pop(published);
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
        _images.length,
      );
      if (mounted) setState(() => _images.addAll(images));
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

  void _moveImage(int from, int to) {
    setState(() => _images.insert(to, _images.removeAt(from)));
  }

  Future<void> _publish() async {
    if (_submitting || _picking || !_form.currentState!.validate()) return;
    final text = _text.text.trim();
    final summary = _summary.text.trim();
    final draft = AnnouncementDraft(
      title: _title.text.trim(),
      summary: summary.isEmpty ? null : summary,
      text: text.isEmpty ? null : text,
      images: List.unmodifiable(_images),
    );
    final contentError = draft.validateContent();
    if (contentError != null) {
      setState(() => _publishError = contentError);
      return;
    }
    setState(() {
      _submitting = true;
      _publishError = null;
    });
    try {
      final repository = await ref.read(announcementsRepositoryProvider.future);
      if (!mounted) return;
      if (ref.read(sessionProvider).role != UserRole.administrador) {
        throw const ApiException(
          'Solo el administrador puede publicar novedades.',
        );
      }
      await repository.publish(draft);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _publishError = apiMessageOf(error);
        });
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(announcementsPageProvider);
    ref.invalidate(latestAnnouncementsProvider);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Novedad publicada')));
    _close(published: true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _picking;
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: busy ? null : _close,
          ),
          title: const Text('Crear nueva novedad'),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Agregá un título y publicá con texto, imágenes o ambos.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _title,
                      enabled: !_submitting,
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
                      controller: _summary,
                      enabled: !_submitting,
                      maxLength: AnnouncementDraft.maxSummaryLength,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Resumen (opcional)',
                      ),
                      validator: AnnouncementDraft.validateSummary,
                    ),
                    const SizedBox(height: 12),
                    AnnouncementMarkdownEditor(
                      controller: _text,
                      enabled: !_submitting,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Imágenes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Hasta 5 imágenes JPEG o PNG, de 5 MB y 6000 × 6000 px como máximo cada una. La primera será la portada.',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed:
                            busy ||
                                _images.length >=
                                    AnnouncementImageUpload.maxCount
                            ? null
                            : _addImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _picking ? 'Cargando imágenes…' : 'Agregar imágenes',
                        ),
                      ),
                    ),
                    if (_imageError != null)
                      Text(_imageError!, style: errorStyle),
                    for (final (index, image) in _images.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Image.memory(
                          image.bytes,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 144,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                        title: Text(
                          image.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: index == 0 ? const Text('Portada') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Subir imagen ${image.name}',
                              onPressed: busy || index == 0
                                  ? null
                                  : () => _moveImage(index, index - 1),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: 'Bajar imagen ${image.name}',
                              onPressed: busy || index == _images.length - 1
                                  ? null
                                  : () => _moveImage(index, index + 1),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                            IconButton(
                              tooltip: 'Quitar imagen ${image.name}',
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      _images.removeAt(index);
                                      _imageError = null;
                                    }),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_publishError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_publishError!, style: errorStyle),
                        ),
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: busy ? null : _close,
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: busy ? null : _publish,
                          child: Text(_submitting ? 'Publicando…' : 'Publicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
