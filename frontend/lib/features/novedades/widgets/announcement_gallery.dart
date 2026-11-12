import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../announcement_images.dart';
import '../models/announcement_detail.dart';

/// Recorre imágenes de una sola novedad, completas y sin gestos de ampliación.
class AnnouncementGallery extends StatefulWidget {
  const AnnouncementGallery({
    super.key,
    required this.images,
    required this.onReload,
    this.precache = precacheAnnouncementImage,
  });

  final List<AnnouncementImage> images;
  final VoidCallback? onReload;

  /// Precarga las demás imágenes; se inyecta en las pruebas.
  final AnnouncementImagePrecache precache;

  @override
  State<AnnouncementGallery> createState() => _AnnouncementGalleryState();
}

class _AnnouncementGalleryState extends State<AnnouncementGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _prefetchOthersAfterFrame();
  }

  @override
  void didUpdateWidget(AnnouncementGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = [for (final image in oldWidget.images) image.url];
    final after = [for (final image in widget.images) image.url];
    if (!listEquals(before, after)) _prefetchOthersAfterFrame();
  }

  /// Cuando llega el detalle: precarga las imágenes que todavía no se ven.
  /// La visible la pide la propia galería.
  void _prefetchOthersAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var i = 0; i < widget.images.length; i++) {
        if (i == _index) continue;
        widget.precache(
          context,
          announcementNetworkImage(widget.images[i].url),
        );
      }
    });
  }

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
    if (widget.images.isEmpty) return const SizedBox.shrink();
    final count = widget.images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          height: MediaQuery.sizeOf(context).width < 600 ? 420 : 600,
          child: PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => Image.network(
              widget.images[index].url,
              key: ValueKey('announcement-image-${widget.images[index].id}'),
              width: double.infinity,
              fit: BoxFit.contain,
              cacheWidth: kAnnouncementImageCacheWidth,
              semanticLabel: 'Imagen ${index + 1} de $count de la novedad',
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stack) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_outlined, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'No pudimos cargar esta imagen.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onReload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Volver a cargar imágenes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Imagen anterior',
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              for (var i = 0; i < count; i++)
                IconButton(
                  tooltip: 'Imagen ${i + 1} de $count',
                  onPressed: () => _goTo(i),
                  isSelected: i == _index,
                  iconSize: 12,
                  icon: Icon(
                    i == _index ? Icons.circle : Icons.circle_outlined,
                  ),
                ),
              IconButton(
                tooltip: 'Imagen siguiente',
                onPressed: _index < count - 1 ? () => _goTo(_index + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Center(child: Text('Imagen ${_index + 1} de $count')),
        ],
      ],
    );
  }
}
