import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/router/app_sections.dart';

class HomeShortcuts extends StatelessWidget {
  const HomeShortcuts({
    super.key,
    required this.sections,
    required this.onSelected,
  });

  final List<AppSection> sections;
  final ValueChanged<AppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 720
            ? 4
            : textScale > 1.3
            ? 1
            : 2;
        final gap = columns == 4 ? 24.0 : 16.0;
        final size = math.min(
          columns == 4 ? 176.0 : 200.0,
          (constraints.maxWidth - gap * (columns - 1)) / columns,
        );
        return Wrap(
          alignment: columns == 4
              ? WrapAlignment.center
              : WrapAlignment.spaceBetween,
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final section in sections)
              SizedBox.square(
                dimension: size,
                child: OutlinedButton(
                  key: Key('home-shortcut-${section.slug}'),
                  onPressed: () => onSelected(section),
                  style:
                      OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        foregroundColor: theme.colorScheme.primary,
                        elevation: 0,
                        shadowColor: Colors.black.withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ).copyWith(
                        elevation: WidgetStateProperty.resolveWith(
                          (states) =>
                              states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                              ? 2
                              : 0,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          final highlighted =
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused);
                          return Color.alphaBlend(
                            theme.colorScheme.primary.withValues(
                              alpha: highlighted
                                  ? 0.14
                                  : section.slug == 'disponibilidad'
                                  ? 0.08
                                  : 0,
                            ),
                            theme.colorScheme.surfaceContainerLowest,
                          );
                        }),
                        side: WidgetStateProperty.resolveWith(
                          (states) => BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: states.contains(WidgetState.focused)
                                  ? 0.8
                                  : 0.22,
                            ),
                            width: states.contains(WidgetState.focused) ? 2 : 1,
                          ),
                        ),
                      ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(section.icon, size: size < 150 ? 32 : 48),
                      const SizedBox(height: 12),
                      Text(
                        section.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
