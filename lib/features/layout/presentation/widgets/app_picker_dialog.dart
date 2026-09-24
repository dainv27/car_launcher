import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Callback for when an app is selected from the picker
typedef AppSelectedCallback = Future<void> Function(PaneApp app);

/// Dialog for picking an app to assign to a pane.
/// Shows the list of installed apps with search.
class AppPickerDialog extends ConsumerStatefulWidget {
  const AppPickerDialog({
    super.key,
    required this.paneIndex,
    this.currentApp,
    required this.onAppSelected,
    this.onRemove,
  });

  final int paneIndex;
  final PaneApp? currentApp;
  final AppSelectedCallback onAppSelected;
  final VoidCallback? onRemove;

  @override
  ConsumerState<AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends ConsumerState<AppPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final loadState = ref.watch(installedAppsProvider);
    final apps = loadState.apps;
    final appsLoading = loadState.isLoading;

    final filtered = _query.isEmpty
        ? apps
        : apps.where((app) {
            final name = (app['appName'] ?? '').toLowerCase();
            final pkg = (app['packageName'] ?? '').toLowerCase();
            return name.contains(_query) || pkg.contains(_query);
          }).toList();

    return Dialog(
      backgroundColor: context.palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.currentApp != null &&
                          widget.currentApp!.packageName.isNotEmpty
                      ? 'Change Pane ${widget.paneIndex + 1} App'
                      : 'Assign App to Pane ${widget.paneIndex + 1}',
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onRemove != null)
                  TextButton.icon(
                    onPressed: widget.onRemove,
                    icon: Icon(Icons.remove_circle_outline,
                        color: context.palette.danger, size: 18),
                    label: Text('Remove',
                        style: TextStyle(color: context.palette.danger)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Search bar
            TextField(
              style: TextStyle(color: context.palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: TextStyle(color: context.palette.textTertiary),
                prefixIcon: Icon(Icons.search, color: context.palette.textSecondary),
                filled: true,
                fillColor: context.palette.foreground.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            const SizedBox(height: 12),
            // App list
            Expanded(
              child: appsLoading
                  ? Center(
                      child: CircularProgressIndicator(color: context.palette.textSecondary))
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            apps.isEmpty
                                ? 'No apps found'
                                : 'No matching apps',
                            style: TextStyle(
                                color: context.palette.textTertiary, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            final appName = app['appName'] ?? '';
                            final pkgName = app['packageName'] ?? '';
                            final isSelected =
                                widget.currentApp?.packageName == pkgName;

                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: context.palette.foreground.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.android,
                                    color: context.palette.success, size: 24),
                              ),
                              title: Text(
                                appName,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.palette.success
                                      : context.palette.textPrimary,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                pkgName,
                                style: TextStyle(
                                    color: context.palette.textTertiary, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: context.palette.success, size: 20)
                                  : null,
                              onTap: () async {
                                await widget.onAppSelected(PaneApp(
                                  packageName: pkgName,
                                  appName: appName,
                                ));
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          },
                        ),
            ),
            const SizedBox(height: 8),
            // Cancel button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel',
                    style: TextStyle(color: context.palette.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
