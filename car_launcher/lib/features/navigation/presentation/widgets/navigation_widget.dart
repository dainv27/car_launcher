/// Enhanced Navigation widget — shows navigation status, provider switcher, and quick launch
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/navigation/data/navigation_service.dart';
import 'package:car_launcher/features/navigation/presentation/providers/navigation_providers.dart';

/// Enhanced navigation widget with provider switching and rich status display
class NavigationWidget extends ConsumerWidget {
  const NavigationWidget({
    super.key,
    required this.widgetId,
    required this.onLongPress,
  });

  final String widgetId;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationStateProvider);
    final controller = ref.read(navigationStateProvider.notifier);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: navState.isActive ? const Color(0xFF4CAF50) : Colors.white12,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: navState.isActive
            ? _buildActiveNav(context, ref, navState, controller)
            : _buildIdle(context, ref, controller),
      ),
    );
  }

  Widget _buildActiveNav(
    BuildContext context,
    WidgetRef ref,
    NavigationStateModel navState,
    dynamic controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: icon + ETA + distance
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation,
                color: Color(0xFF4CAF50),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              navState.eta,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              navState.distance,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),

        if (navState.destination.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'To: ${navState.destination}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        if (navState.nextTurn.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _turnIcon(navState.nextTurn),
                color: const Color(0xFF4CAF50),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  navState.nextTurn,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 8),

        // Provider badge. Google Maps exposes no public stop-guidance API.
        Row(
          children: [
            // Provider badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                navState.currentProvider.displayName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdle(BuildContext context, WidgetRef ref, dynamic controller) {
    final currentProvider = ref.watch(navProviderProvider);
    final availableProviders = ref.watch(availableNavProvidersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.navigation, color: Colors.white38, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Navigation',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Not active',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Launch button
            IconButton(
              icon: const Icon(
                Icons.directions,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () => controller.launchNavigation(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Provider switcher
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableProviders.map((provider) {
              final isSelected = provider == currentProvider;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => controller.switchProvider(provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      provider.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _turnIcon(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('left')) return Icons.turn_left;
    if (lower.contains('right')) return Icons.turn_right;
    if (lower.contains('u-turn') || lower.contains('uturn')) {
      return Icons.u_turn_left;
    }
    if (lower.contains('straight') || lower.contains('continue')) {
      return Icons.straight;
    }
    if (lower.contains('roundabout') || lower.contains('round')) {
      return Icons.roundabout_left;
    }
    if (lower.contains('exit')) return Icons.exit_to_app;
    return Icons.navigation;
  }
}
