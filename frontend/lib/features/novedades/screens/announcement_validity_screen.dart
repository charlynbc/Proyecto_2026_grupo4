import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../models/admin_announcement.dart';
import '../models/announcement_draft.dart';
import '../providers/announcements_provider.dart';
import '../widgets/announcement_visibility_fields.dart';
import 'admin_announcements_screen.dart' show AnnouncementStatusLabel;

/// Cambiar desde y hasta cuándo se ve una novedad ya publicada.
class AnnouncementValidityScreen extends ConsumerWidget {
  const AnnouncementValidityScreen({super.key, required this.id});

  final int id;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(UserRole.administrador.announcementsPath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminAnnouncementsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () => _close(context),
        ),
        title: const Text('Cambiar vigencia'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: state.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando novedad…'),
                  ],
                ),
              ),
              error: (error, _) => Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text('No pudimos cargar la novedad.'),
                  const SizedBox(height: 8),
                  Text(apiMessageOf(error), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(adminAnnouncementsProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
              data: (items) {
                final item = items.where((i) => i.id == id).firstOrNull;
                if (item == null) {
                  return Column(
                    children: [
                      const Text(
                        'No encontramos esta novedad. Puede que otra persona '
                        'la haya eliminado.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.go(
                          UserRole.administrador.announcementsPath,
                        ),
                        child: const Text('Volver a la Cartelera'),
                      ),
                    ],
                  );
                }
                return _ValidityForm(
                  item: item,
                  onClose: () => _close(context),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ValidityForm extends ConsumerStatefulWidget {
  const _ValidityForm({required this.item, required this.onClose});

  final AdminAnnouncement item;
  final VoidCallback onClose;

  @override
  ConsumerState<_ValidityForm> createState() => _ValidityFormState();
}

class _ValidityFormState extends ConsumerState<_ValidityForm> {
  final _form = GlobalKey<FormState>();
  final _visibility = AnnouncementVisibilityController();
  bool _submitting = false;
  String? _visibilityError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _visibility.fill(
      from: widget.item.visibleFrom,
      until: widget.item.visibleUntil,
    );
  }

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  void _clearVisibilityError() {
    if (_visibilityError != null) setState(() => _visibilityError = null);
  }

  Future<void> _save() async {
    if (_submitting) return;
    _visibility.validating = true;
    final valid = _form.currentState!.validate();
    _visibility.validating = false;
    if (!valid) return;
    final from = _visibility.from;
    final until = _visibility.until;
    final rangeError = AnnouncementDraft.validateVisibilityRange(
      from,
      until,
      ref.read(announcementClockProvider)(),
    );
    if (rangeError != null) {
      setState(() {
        _saveError = null;
        _visibilityError = rangeError;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _saveError = null;
      _visibilityError = null;
    });
    try {
      if (ref.read(sessionProvider).role != UserRole.administrador) {
        throw const ApiException(
          'Solo el administrador puede gestionar la cartelera.',
        );
      }
      final repository = await ref.read(announcementsRepositoryProvider.future);
      await repository.updateValidity(widget.item.id, from: from, until: until);
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
        .showSnackBar(const SnackBar(content: Text('Vigencia actualizada')));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.displayTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          AnnouncementStatusLabel(
            status: widget.item.status,
            id: widget.item.id,
          ),
          const SizedBox(height: 20),
          AnnouncementVisibilityFields(
            controller: _visibility,
            enabled: !_submitting,
            onEdited: _clearVisibilityError,
          ),
          if (_visibilityError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(_visibilityError!, style: errorStyle),
              ),
            ),
          const SizedBox(height: 24),
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
                child: Text(_submitting ? 'Guardando…' : 'Guardar vigencia'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
