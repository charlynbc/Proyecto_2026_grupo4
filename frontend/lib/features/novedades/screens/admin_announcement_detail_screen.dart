import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../../core/utils/ui_date_time.dart';
import '../../auth/models/user_role.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/admin_announcement_detail.dart';
import '../providers/announcements_provider.dart';
import '../repositories/announcements_repository.dart';
import '../widgets/announcement_gallery.dart';
import '../widgets/announcement_markdown.dart';
import 'admin_announcements_screen.dart' show AnnouncementStatusLabel;

/// El detalle de una novedad para el administrador, sea cual sea su estado.
/// Se arma con GET /api/admin/anuncios/{id}: el detalle público responde 404
/// para las programadas y las vencidas. Muestra además el estado y las fechas
/// de vigencia.
class AdminAnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementDetailScreen({super.key, required this.id});

  final int? id;

  @override
  ConsumerState<AdminAnnouncementDetailScreen> createState() =>
      _AdminAnnouncementDetailScreenState();
}

class _AdminAnnouncementDetailScreenState
    extends ConsumerState<AdminAnnouncementDetailScreen> {
  AdminAnnouncementDetail? _lastDetail;

  @override
  void didUpdateWidget(covariant AdminAnnouncementDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _lastDetail = null;
  }

  void _reload() {
    if (widget.id != null) {
      ref.invalidate(adminAnnouncementDetailProvider(widget.id!));
    }
  }

  void _back() => context.go(UserRole.administrador.announcementsPath);

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
    final state = id == null
        ? null
        : ref.watch(adminAnnouncementDetailProvider(id));
    if (id != null) {
      ref.listen(adminAnnouncementDetailProvider(id), (_, next) {
        if (next is AsyncData<AdminAnnouncementDetail>) {
          _lastDetail = next.value;
        }
        // Si la novedad ya no existe, la lista de gestión tiene que
        // actualizarse al volver.
        if (next is AsyncError && next.error is AnnouncementNotFoundException) {
          ref.invalidate(adminAnnouncementsProvider);
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
          tooltip: 'Volver a novedades',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Novedad'),
        actions: const [LogoutButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          key: ValueKey('admin-announcement-detail-$id'),
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
                    label: const Text('Volver a novedades'),
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
    AdminAnnouncementDetail detail,
    bool loading,
  ) {
    final theme = Theme.of(context);
    final summary = detail.summary?.trim();
    final text = detail.text;
    final from = detail.visibleFrom;
    final until = detail.visibleUntil;
    final position = detail.position;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          detail.displayTitle,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        AnnouncementStatusLabel(status: detail.status, id: detail.id),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('admin-detail-edit'),
            onPressed: () => context.push(
              '${UserRole.administrador.announcementsPath}/${detail.id}/editar',
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Publicado el ${DateFormat('dd/MM/yyyy').format(detail.publishedAt.toLocal())}',
          style: muted,
        ),
        Text(
          from == null
              ? 'Se ve desde: la publicación'
              : 'Se ve desde: ${formatUiDateTime(from)}',
          style: muted,
        ),
        Text(
          until == null
              ? 'Sin fecha de fin'
              : 'Se deja de ver: ${formatUiDateTime(until)}',
          style: muted,
        ),
        if (position != null)
          Text('En el carrusel: posición $position', style: muted),
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
          AnnouncementMarkdown(text: text, onTapLink: _openLink),
        ],
      ],
    );
  }
}
