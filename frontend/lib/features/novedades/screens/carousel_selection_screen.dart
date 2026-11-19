import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../models/admin_announcement.dart';
import '../providers/announcements_provider.dart';

/// Elegir qué novedades salen en el carrusel del Inicio: hasta cinco
/// posiciones, con huecos permitidos. Guardar reemplaza toda la selección.
class CarouselSelectionScreen extends ConsumerWidget {
  const CarouselSelectionScreen({super.key});

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(UserRole.administrador.announcementsPath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = ref.watch(adminAnnouncementsProvider);
    final carousel = ref.watch(adminCarouselProvider);
    void retry() {
      ref.invalidate(adminAnnouncementsProvider);
      ref.invalidate(adminCarouselProvider);
    }

    final Widget body;
    if (announcements.isLoading || carousel.isLoading) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando el carrusel…'),
          ],
        ),
      );
    } else if (announcements.hasError || carousel.hasError) {
      body = Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('No pudimos cargar el carrusel.'),
          const SizedBox(height: 8),
          Text(
            apiMessageOf((announcements.error ?? carousel.error)!),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
        ],
      );
    } else if (announcements.requireValue.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Todavía no hay novedades para elegir.',
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = _CarouselForm(
        announcements: announcements.requireValue,
        slots: carousel.requireValue,
        onClose: () => _close(context),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () => _close(context),
        ),
        title: const Text('Carrusel del Inicio'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _CarouselForm extends ConsumerStatefulWidget {
  const _CarouselForm({
    required this.announcements,
    required this.slots,
    required this.onClose,
  });

  final List<AdminAnnouncement> announcements;
  final List<CarouselSlot> slots;
  final VoidCallback onClose;

  @override
  ConsumerState<_CarouselForm> createState() => _CarouselFormState();
}

class _CarouselFormState extends ConsumerState<_CarouselForm> {
  static const _notActiveMessage =
      'No está vigente: no se muestra a los socios.';

  /// La novedad elegida en cada posición (índice 0 = posición 1), o `null`.
  late final List<int?> _selection;
  bool _submitting = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final known = {for (final a in widget.announcements) a.id};
    _selection = List.filled(AdminAnnouncement.maxCarouselSlots, null);
    for (final slot in widget.slots) {
      final index = slot.position - 1;
      if (index >= 0 &&
          index < _selection.length &&
          known.contains(slot.announcementId)) {
        _selection[index] = slot.announcementId;
      }
    }
  }

  AdminAnnouncement? _announcement(int? id) =>
      widget.announcements.where((a) => a.id == id).firstOrNull;

  Future<void> _save() async {
    if (_submitting) return;
    final chosen = _selection.whereType<int>().toList();
    if (chosen.toSet().length != chosen.length) {
      setState(() => _saveError = 'Elegí cada novedad una sola vez.');
      return;
    }
    // La selección completa, con sus huecos: guardar reemplaza todo lo anterior.
    final slots = [
      for (final (index, id) in _selection.indexed)
        if (id != null) CarouselSlot(position: index + 1, announcementId: id),
    ];
    setState(() {
      _submitting = true;
      _saveError = null;
    });
    try {
      if (ref.read(sessionProvider).role != UserRole.administrador) {
        throw const ApiException(
          'Solo el administrador puede gestionar la cartelera.',
        );
      }
      final repository = await ref.read(announcementsRepositoryProvider.future);
      await repository.saveCarousel(slots);
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Carrusel guardado')));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorStyle = TextStyle(color: theme.colorScheme.error);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Elegí hasta 5 novedades para el carrusel del Inicio. Podés dejar '
          'posiciones vacías. Al guardar se reemplaza toda la selección '
          'anterior.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Una novedad que no está vigente no se muestra a los socios aunque '
          'esté elegida.',
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < _selection.length; index++) ...[
          DropdownButtonFormField<int?>(
            key: ValueKey('carousel-slot-${index + 1}'),
            initialValue: _selection[index],
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(labelText: 'Posición ${index + 1}'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Sin novedad'),
              ),
              for (final item in widget.announcements)
                DropdownMenuItem<int?>(
                  value: item.id,
                  child: Text(
                    '${item.displayTitle} (${item.status.label})',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _submitting
                ? null
                : (id) => setState(() {
                    _selection[index] = id;
                    _saveError = null;
                  }),
          ),
          if (_announcement(_selection[index]) case final chosen?
              when chosen.status != AnnouncementStatus.active)
            Padding(
              key: ValueKey('carousel-warning-${index + 1}'),
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _notActiveMessage,
                style: TextStyle(color: theme.colorScheme.tertiary),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(_saveError!, style: errorStyle),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: _submitting ? null : widget.onClose,
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: Text(_submitting ? 'Guardando…' : 'Guardar carrusel'),
            ),
          ],
        ),
      ],
    );
  }
}
