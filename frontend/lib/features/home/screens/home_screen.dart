import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/branding.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_sections.dart';
import '../../auth/models/user_role.dart';
import '../../auth/widgets/logout_button.dart';
import '../../cuenta/providers/account_provider.dart';
import '../../novedades/providers/announcements_provider.dart';
import '../widgets/announcements_carousel.dart';
import '../widgets/home_shortcuts.dart';

/// Inicio del socio; las tarjetas abren su detalle y Cartelera abre el listado.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
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

  void _refreshIfExpired() {
    final loadedAt = _loadedAt;
    if (loadedAt != null &&
        DateTime.now().difference(loadedAt) >= const Duration(minutes: 55)) {
      _loadedAt = null;
      ref.invalidate(latestAnnouncementsProvider);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasActive) _refreshIfExpired();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El indexedStack conserva Inicio. Al volver, renovar las URL por vencer.
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshIfExpired();
      });
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final account = accountState.isLoading ? null : accountState.asData?.value;
    final announcements = ref.watch(latestAnnouncementsProvider);
    ref.listen(latestAnnouncementsProvider, (_, next) {
      if (next is AsyncData) _loadedAt = DateTime.now();
    });
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    void openBillboard() => context.go('/socio/cartelera');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 136,
        titleSpacing: wide ? 32 : 20,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/images/logo.svg',
                  key: const Key('home-logo'),
                  width: 80,
                  height: 80,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 6),
                Text(
                  kMutualistaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (wide && account != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${account.name} ${account.lastName}',
                    style: theme.textTheme.labelLarge,
                  ),
                  Text(
                    'Socio',
                    key: const Key('home-user-role'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const LogoutButton(),
          if (wide) const SizedBox(width: 16),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 32 : 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const Key('home-welcome-banner'),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      theme.colorScheme.primary.withValues(alpha: 0.09),
                      Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account == null
                              ? 'Bienvenido/a'
                              : 'Bienvenido/a, ${account.name}',
                          key: const Key('home-greeting'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!wide) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Socio',
                            key: const Key('home-user-role'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Novedades de la mutualista',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                announcements.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () => const _NewsStatus(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Cargando novedades…'),
                      ],
                    ),
                  ),
                  error: (error, _) => _NewsStatus(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text('No pudimos cargar las novedades.'),
                        const SizedBox(height: 8),
                        Text(apiMessageOf(error), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(latestAnnouncementsProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? const _NewsStatus(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_outlined, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Todavía no hay novedades publicadas.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : AnnouncementsCarousel(
                          key: ObjectKey(items),
                          announcements: items,
                          onOpen: (id) => context.go('/socio/cartelera/$id'),
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: openBillboard,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Ver todas las novedades'),
                  ),
                ),
                const SizedBox(height: 16),
                HomeShortcuts(
                  sections: UserRole.socio.sections.skip(1).toList(),
                  onSelected: (section) =>
                      context.go(UserRole.socio.sectionPath(section)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsStatus extends StatelessWidget {
  const _NewsStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 280),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    alignment: Alignment.center,
    child: child,
  );
}
