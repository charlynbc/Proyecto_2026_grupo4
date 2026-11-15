import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../../core/utils/ui_date_time.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/admin_announcement.dart';
import '../providers/announcements_provider.dart';

/// La Cartelera del administrador: todas las novedades con su estado, su
/// vigencia y su lugar en el carrusel, y las acciones para gestionarlas.
class AdminAnnouncementsScreen extends ConsumerStatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  ConsumerState<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends ConsumerState<AdminAnnouncementsScreen> {
  static final _listPath = UserRole.administrador.announcementsPath;

  /// La novedad que se está eliminando. Mientras hay una, no se puede tocar
  /// ninguna acción: evita duplicar el envío.
  int? _busyId;

  void _refresh() => ref.invalidate(adminAnnouncementsProvider);

  Future<void> _create() async {
    final published = await context.push<bool>('$_listPath/nueva');
    if (!mounted || published != true) return;
    invalidateAnnouncementViews(ref);
  }

  Future<bool> _confirmDelete(AdminAnnouncement item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta novedad?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Se elimina para siempre y no se puede recuperar. Se borra '
                'también de la cartelera y del carrusel.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar novedad'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _delete(AdminAnnouncement item) async {
    if (_busyId != null) return;
    if (!await _confirmDelete(item) || !mounted) return;
    setState(() => _busyId = item.id);
    String? failure;
    try {
      if (ref.read(sessionProvider).role != UserRole.administrador) {
        throw const ApiException(
          'Solo el administrador puede gestionar la cartelera.',
        );
      }
      final repository = await ref.read(announcementsRepositoryProvider.future);
      await repository.delete(item.id);
    } catch (error) {
      failure = apiMessageOf(error);
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    // También tras un error: si otra persona ya la eliminó (404), la lista
    // tiene que dejar de mostrarla.
    invalidateAnnouncementViews(ref);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure ?? 'Novedad eliminada')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAnnouncementsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al Inicio',
          onPressed: () => context.go(UserRole.administrador.homePath),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Cartelera',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [LogoutButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: state.isLoading || _busyId != null
                            ? null
                            : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar novedades'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busyId != null
                            ? null
                            : () => context.push('$_listPath/carrusel'),
                        icon: const Icon(Icons.view_carousel_outlined),
                        label: const Text('Elegir carrusel'),
                      ),
                      FilledButton.icon(
                        onPressed: _busyId != null ? null : _create,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear nueva novedad'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                state.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando novedades…'),
                      ],
                    ),
                  ),
                  error: (error, _) => Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 40),
                      const SizedBox(height: 12),
                      const Text('No pudimos cargar las novedades.'),
                      const SizedBox(height: 8),
                      Text(apiMessageOf(error), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (items) => items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            'Todavía no hay novedades publicadas.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in items) ...[
                              _AdminAnnouncementCard(
                                item: item,
                                busy: _busyId != null,
                                onChangeValidity: () => context.push(
                                  '$_listPath/${item.id}/vigencia',
                                ),
                                onDelete: () => _delete(item),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAnnouncementCard extends StatelessWidget {
  const _AdminAnnouncementCard({
    required this.item,
    required this.busy,
    required this.onChangeValidity,
    required this.onDelete,
  });

  final AdminAnnouncement item;
  final bool busy;
  final VoidCallback onChangeValidity;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = item.visibleFrom;
    final until = item.visibleUntil;
    final position = item.position;
    return Card(
      key: ValueKey('admin-announcement-${item.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            AnnouncementStatusLabel(status: item.status, id: item.id),
            const SizedBox(height: 8),
            Text(
              from == null
                  ? 'Se ve desde: la publicación'
                  : 'Se ve desde: ${formatUiDateTime(from)}',
            ),
            Text(
              until == null
                  ? 'Sin fecha de fin'
                  : 'Se deja de ver: ${formatUiDateTime(until)}',
            ),
            if (position != null) Text('En el carrusel: posición $position'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('admin-validity-${item.id}'),
                  onPressed: busy ? null : onChangeValidity,
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Cambiar vigencia'),
                ),
                TextButton.icon(
                  key: ValueKey('admin-delete-${item.id}'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// El estado de una novedad como etiqueta con texto: no depende solo del color.
class AnnouncementStatusLabel extends StatelessWidget {
  const AnnouncementStatusLabel({
    super.key,
    required this.status,
    required this.id,
  });

  final AnnouncementStatus status;
  final int id;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (status) {
      AnnouncementStatus.scheduled => (
        Icons.schedule,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      AnnouncementStatus.active => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      AnnouncementStatus.expired => (
        Icons.history,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        key: ValueKey('admin-status-$id'),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
