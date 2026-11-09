import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../novedades/models/announcement.dart';

/// Una portada por novedad. No consulta ni representa su detalle.
class AnnouncementsCarousel extends StatefulWidget {
  const AnnouncementsCarousel({
    super.key,
    required this.announcements,
    required this.onOpen,
  });

  final List<Announcement> announcements;
  final ValueChanged<int> onOpen;

  @override
  State<AnnouncementsCarousel> createState() => _AnnouncementsCarouselState();
}

class _AnnouncementsCarouselState extends State<AnnouncementsCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.announcements.length;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final height =
            (constraints.maxWidth >= 720 ? 280.0 : 320.0) +
            (textScale > 1 ? (textScale - 1) * 180 : 0);
        return Column(
          children: [
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: count,
                      onPageChanged: (index) => setState(() => _index = index),
                      itemBuilder: (context, index) => _AnnouncementCard(
                        announcement: widget.announcements[index],
                        onOpen: () =>
                            widget.onOpen(widget.announcements[index].id),
                      ),
                    ),
                  ),
                  if (count > 1) ...[
                    Positioned(
                      left: 12,
                      top: 56,
                      child: IconButton.filledTonal(
                        tooltip: 'Novedad anterior',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.95),
                          foregroundColor: colors.primary,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.65,
                          ),
                          disabledForegroundColor: colors.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 56,
                      child: IconButton.filledTonal(
                        tooltip: 'Novedad siguiente',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.95),
                          foregroundColor: colors.primary,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.65,
                          ),
                          disabledForegroundColor: colors.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        onPressed: _index < count - 1
                            ? () => _goTo(_index + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (count > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    IconButton(
                      tooltip: 'Novedad ${i + 1} de $count',
                      isSelected: i == _index,
                      onPressed: () => _goTo(i),
                      iconSize: 12,
                      icon: Icon(
                        i == _index ? Icons.circle : Icons.circle_outlined,
                        color: i == _index
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.onOpen});

  final Announcement announcement;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = announcement.summary?.trim();
    Widget placeholder() => ColoredBox(
      key: Key('announcement-placeholder-${announcement.id}'),
      color: theme.colorScheme.primaryContainer,
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: Icon(
          Icons.campaign_outlined,
          size: 64,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );

    return Semantics(
      button: true,
      child: Material(
        child: InkWell(
          key: Key('announcement-${announcement.id}'),
          onTap: onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (announcement.coverUrl == null)
                placeholder()
              else
                Image.network(
                  announcement.coverUrl!,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  loadingBuilder: (context, image, progress) =>
                      progress == null ? image : placeholder(),
                  errorBuilder: (_, _, _) => placeholder(),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Color.lerp(
                    theme.colorScheme.primary,
                    const Color(0xFF061C36),
                    0.75,
                  )!.withValues(alpha: 0.9),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        announcement.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (summary != null && summary.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy')
                                .format(announcement.publishedAt.toLocal()),
                            style: const TextStyle(color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver novedad',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
