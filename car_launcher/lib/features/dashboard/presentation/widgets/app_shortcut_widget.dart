import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/widget_providers.dart';

/// App shortcut widget — quick launch for a single configured app
class AppShortcutWidget extends ConsumerWidget {
  const AppShortcutWidget({
    super.key,
    required this.widgetId,
    required this.onLongPress,
  });

  final String widgetId;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(widgetListProvider);
    final widget = widgets.where((w) => w.id == widgetId).firstOrNull;
    final packageName = widget?.data['packageName'] ?? '';
    final appName = widget?.data['appName'] ?? 'App';

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () {
        if (packageName.isNotEmpty) {
          ref.read(launcherServiceProvider).launchApp(packageName);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconForApp(packageName),
                color: Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForApp(String packageName) {
    final name = packageName.toLowerCase();
    if (name.contains('map') || name.contains('waze') || name.contains('nav')) {
      return Icons.navigation;
    }
    if (name.contains('music') || name.contains('spotify')) {
      return Icons.music_note;
    }
    if (name.contains('phone') || name.contains('dial')) {
      return Icons.phone;
    }
    if (name.contains('message') || name.contains('sms')) {
      return Icons.message;
    }
    return Icons.apps;
  }
}
