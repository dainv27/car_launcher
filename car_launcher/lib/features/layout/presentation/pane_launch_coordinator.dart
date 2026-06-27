import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';

/// Coordinates launching apps when native embedding is unavailable.
class PaneLaunchCoordinator {
  PaneLaunchCoordinator._();

  static String? _lastLaunchedKey;
  static bool _startupLaunched = false;
  static bool? _embeddingSupported;

  static void invalidate() {
    _lastLaunchedKey = null;
    _startupLaunched = false;
  }

  static Future<bool> launchForLayout(
    LauncherService launcher,
    LayoutModel model, {
    bool force = false,
    bool useSplitScreenFallback = true,
  }) async {
    if (!useSplitScreenFallback) return false;
    if (!force && _startupLaunched) return false;

    final apps = _appsToLaunch(model);
    if (apps.isEmpty) return false;

    final key = apps.map((a) => a.packageName).join('|');
    if (!force && key == _lastLaunchedKey) return false;

    bool launched = await launcher.launchApp(apps[0].packageName);

    if (launched) {
      _lastLaunchedKey = key;
      _startupLaunched = true;
    }

    return launched;
  }

  /// Auto-launch assigned apps on startup when embedding is not supported.
  static Future<bool> launchOnStartup(
    LauncherService launcher,
    LayoutModel model,
  ) async {
    _embeddingSupported ??= await launcher.isEmbeddingSupported();
    if (_embeddingSupported == true) return false;

    return launchForLayout(launcher, model);
  }

  static List<PaneApp> _appsToLaunch(LayoutModel model) {
    final assigned = model.assignedPaneApps;
    if (assigned.isEmpty) return const [];

    return assigned.take(1).toList();
  }
}
