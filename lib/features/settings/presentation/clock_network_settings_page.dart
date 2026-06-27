import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/home_indicator.dart';

/// CarPlay-style Clock & Network settings screen.
class ClockNetworkSettingsPage extends ConsumerWidget {
  const ClockNetworkSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(carPlaySettingsProvider);
    final notifier = ref.read(carPlaySettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: TextButton.icon(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/settings');
                      }
                    },
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                    label: const Text(
                      'Settings',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Text(
                    'Clock & Network',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _CarPlayToggleTile(
                        title: 'Dynamic Clock and Network',
                        description:
                            'When this feature is enabled, the clock and network '
                            'signal will be visible until the moment you touch the '
                            'screen. When touched, they will automatically hide and '
                            'be shown after 5 seconds of inactivity. This feature '
                            'works only when the Dock is not pinned.',
                        value: settings.dynamicClockNetwork,
                        onChanged: notifier.setDynamicClockNetwork,
                      ),
                      const SizedBox(height: 28),
                      _CarPlayToggleTile(
                        title: '24-Hour Time',
                        value: settings.use24HourTime,
                        onChanged: notifier.setUse24HourTime,
                      ),
                      const SizedBox(height: 28),
                      _CarPlayToggleTile(
                        title: 'VPN Status',
                        description:
                            'When enabled, VPN status is shown next to the network signal.',
                        value: settings.showVpnStatus,
                        onChanged: notifier.setShowVpnStatus,
                      ),
                      const SizedBox(height: 28),
                      _CarPlayToggleTile(
                        title: 'Pin Dock',
                        description:
                            'Keep dock status always visible (disables dynamic hide on dock).',
                        value: settings.dockPinned,
                        onChanged: notifier.setDockPinned,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

class _CarPlayToggleTile extends StatelessWidget {
  const _CarPlayToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CupertinoSwitch(
              value: value,
              activeTrackColor: CarPlayTheme.toggleOn,
              inactiveTrackColor: CarPlayTheme.toggleOff,
              onChanged: onChanged,
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 10),
          Text(
            description!,
            style: const TextStyle(
              color: CarPlayTheme.secondaryText,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
