import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/providers/layout_providers.dart';

/// LayoutPicker — UI for selecting layout type and ratio
class LayoutPicker extends ConsumerWidget {
  const LayoutPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentType = ref.watch(layoutTypeProvider);
    final currentRatio = ref.watch(layoutRatioProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layout type selector
        const Text(
          'Layout Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LayoutType.values.map((type) {
            final isSelected = type == currentType;
            return _LayoutTypeChip(
              type: type,
              isSelected: isSelected,
              onSelected: () {
                ref.read(layoutProvider.notifier).setType(type);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Ratio selector (only show for multi-pane layouts)
        if (currentType != LayoutType.dashboard_01) ...[
          const Text(
            'Pane Ratio',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LayoutRatio.values.map((ratio) {
              final isSelected = ratio == currentRatio;
              return _RatioChip(
                ratio: ratio,
                isSelected: isSelected,
                onSelected: () {
                  ref.read(layoutProvider.notifier).setRatio(ratio);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Chip for selecting layout type
class _LayoutTypeChip extends StatelessWidget {
  const _LayoutTypeChip({
    required this.type,
    required this.isSelected,
    required this.onSelected,
  });

  final LayoutType type;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type.icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(type.displayName),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
      ),
      backgroundColor: Colors.white12,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.white24,
      ),
    );
  }
}

/// Chip for selecting pane ratio
class _RatioChip extends StatelessWidget {
  const _RatioChip({
    required this.ratio,
    required this.isSelected,
    required this.onSelected,
  });

  final LayoutRatio ratio;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(ratio.label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
      ),
      backgroundColor: Colors.white12,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.white24,
      ),
    );
  }
}
