import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../auth/models/user_role.dart';
import '../../auth/widgets/logout_button.dart';
import '../announcement_images.dart';
import '../models/announcement.dart';
import '../providers/announcements_provider.dart';
import '../widgets/announcement_network_image.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen>
    with WidgetsBindingObserver {
  int _page = 0;
  int _scrollReset = 0;
  DateTime? _loadedAt;
  bool _wasActive = false;

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

  void _refresh() => ref.invalidate(announcementsPageProvider(_page));

  void _refreshIfExpired() {
    if (_loadedAt != null &&
        DateTime.now().difference(_loadedAt!) >= const Duration(minutes: 55)) {
      _loadedAt = null;
      _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasActive) _refreshIfExpired();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshIfExpired();
      });
    }
    _wasActive = active;
  }

  void _changePage(int page) {
    setState(() {
      _page = page;
      _loadedAt = null;
    });
  }

  Future<void> _create() async {
    final published = await context.push<bool>(
      '${widget.role.announcementsPath}/nueva',
    );
    if (!mounted || published != true) return;
    setState(() {
      _page = 0;
      _scrollReset++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementsPageProvider(_page));
    ref.listen(announcementsPageProvider(_page), (_, next) {
      if (next is AsyncData) _loadedAt = DateTime.now();
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver al Inicio',
          onPressed: () => context.go(widget.role.homePath),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Novedades',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [LogoutButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          key: ValueKey(('announcements-page', _page, _scrollReset)),
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
                        onPressed: state.isLoading ? null : _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar novedades'),
                      ),
                      if (widget.role == UserRole.administrador)
                        FilledButton.icon(
                          onPressed: _create,
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
                  data: (result) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (result.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(
                            _page == 0
                                ? 'Todavía no hay novedades publicadas.'
                                : 'No hay novedades en esta página.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: result.items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _AnnouncementRow(
                            announcement: result.items[index],
                            listPath: widget.role.announcementsPath,
                          ),
                        ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: _page > 0
                                ? () => _changePage(_page - 1)
                                : null,
                            child: const Text('Anterior'),
                          ),
                          Text('Página ${_page + 1}'),
                          OutlinedButton(
                            onPressed: result.hasNext
                                ? () => _changePage(_page + 1)
                                : null,
                            child: const Text('Siguiente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (state.hasError && _page > 0) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => _changePage(_page - 1),
                      child: const Text('Volver a la página anterior'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({required this.announcement, required this.listPath});

  final Announcement announcement;
  final String listPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = announcement.summary?.trim();
    final narrow = MediaQuery.sizeOf(context).width < 600;
    Widget placeholder() => ColoredBox(
      key: ValueKey('announcement-cover-placeholder-${announcement.id}'),
      color: theme.colorScheme.primaryContainer,
      child: Icon(
        Icons.campaign_outlined,
        size: 36,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );

    return Card(
      key: ValueKey('announcement-row-${announcement.id}'),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go('$listPath/${announcement.id}?desde=cartelera'),
        child: Padding(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: narrow ? 72 : 144,
                  height: narrow ? 88 : 112,
                  child: announcement.coverUrl == null
                      ? placeholder()
                      : AnnouncementNetworkImage(
                          imageId: announcement.coverImageId,
                          url: announcement.coverUrl!,
                          cacheWidth: kAnnouncementImageCacheWidth,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          placeholder: (_) => placeholder(),
                          error: (_) => placeholder(),
                        ),
                ),
              ),
              SizedBox(width: narrow ? 12 : 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.displayTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (summary != null && summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      DateFormat('dd/MM/yyyy')
                          .format(announcement.publishedAt.toLocal()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
