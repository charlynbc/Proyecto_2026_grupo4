import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/announcement_detail.dart';
import '../providers/announcements_provider.dart';
import '../repositories/announcements_repository.dart';
import '../widgets/announcement_gallery.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen({
    super.key,
    required this.id,
    this.backToList = false,
  });

  final int? id;
  final bool backToList;

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen>
    with WidgetsBindingObserver {
  AnnouncementDetail? _lastDetail;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnnouncementDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _lastDetail = null;
      _loadedAt = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) >= const Duration(minutes: 55)) {
      _reload();
    }
  }

  void _reload() {
    if (widget.id != null) {
      ref.invalidate(announcementDetailProvider(widget.id!));
    }
  }

  void _back() {
    context.go(widget.backToList ? '/socio/cartelera' : '/socio/inicio');
  }

  Future<void> _openLink(String text, String? href, String title) async {
    final uri = Uri.tryParse(href ?? '');
    var opened = false;
    if (uri != null &&
        ['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Un enlace fallido no interrumpe la lectura.
      }
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir este enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final state = id == null ? null : ref.watch(announcementDetailProvider(id));
    if (id != null) {
      ref.listen(announcementDetailProvider(id), (_, next) {
        if (next is AsyncData<AnnouncementDetail>) {
          _lastDetail = next.value;
          _loadedAt = DateTime.now();
        }
      });
    }
    final detail = state?.asData?.value ?? _lastDetail;
    final error = state?.error;
    final notFound = id == null || error is AnnouncementNotFoundException;
    final loading = state?.isLoading ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: widget.backToList
              ? 'Volver a novedades'
              : 'Volver al Inicio',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Novedad'),
        actions: const [LogoutButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          key: ValueKey('announcement-detail-$id'),
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notFound)
                  const Text(
                    'No encontramos esta novedad.',
                    style: TextStyle(fontSize: 22),
                  )
                else ...[
                  if (loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Cargando novedad…'),
                  ],
                  if (error != null) ...[
                    const Text('No pudimos cargar la novedad.'),
                    const SizedBox(height: 8),
                    Text(apiMessageOf(error)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ),
                  ],
                  if (detail != null) ...[
                    if (loading || error != null) const SizedBox(height: 24),
                    _content(context, detail, loading),
                  ],
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      widget.backToList
                          ? 'Volver a novedades'
                          : 'Volver al Inicio',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AnnouncementDetail detail,
    bool loading,
  ) {
    final theme = Theme.of(context);
    final title = detail.title?.trim();
    final summary = detail.summary?.trim();
    final text = detail.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null && title.isNotEmpty) ...[
          SelectableText(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Publicado el ${DateFormat('dd/MM/yyyy').format(detail.publishedAt.toLocal())}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (summary != null && summary.isNotEmpty) ...[
          const SizedBox(height: 20),
          SelectableText(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(height: 1.5),
          ),
        ],
        if (detail.images.isNotEmpty) ...[
          const SizedBox(height: 24),
          AnnouncementGallery(
            // Conservar la posición al renovar las URL de las mismas imágenes.
            key: ValueKey(detail.images.map((image) => image.id).join(',')),
            images: detail.images,
            onReload: loading ? null : _reload,
          ),
        ],
        if (text != null && text.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          MarkdownBody(
            data: text,
            selectable: true,
            onTapLink: _openLink,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
              blockSpacing: 16,
            ),
          ),
        ],
      ],
    );
  }
}
