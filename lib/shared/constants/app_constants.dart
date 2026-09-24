/// App-wide constants
class AppConstants {
  static const appName = 'Car Launcher';
  static const appVersion = '1.0.0';

  // Native channel
  static const nativeChannel = 'com.carlauncher/native';
  static const eventChannel = 'com.carlauncher/events';

  // SharedPreferences keys
  static const keyAutoStart = 'auto_start';
  static const keyTheme = 'theme_mode';
  static const keyWallpaper = 'wallpaper_path';
  static const keyLauncherThemeStyle = 'launcher_theme_style';
  static const keyLauncherBackgroundStyle = 'launcher_background_style';
  static const keyWidgets = 'widget_config';
  static const keyFavorites = 'favorite_apps';
  static const keyHiddenApps = 'hidden_apps';
  static const keyDefaultNav = 'default_navigation';
  static const keyDefaultMedia = 'default_media';
  static const keyHomeViewMode = 'home_view_mode';
  static const keyDynamicClockNetwork = 'dynamic_clock_network';
  static const keyUse24HourTime = 'use_24_hour_time';
  static const keyShowVpnStatus = 'show_vpn_status';
  static const keyDockPinned = 'dock_pinned';
  // Brightness
  static const keyScreenBrightness = 'screen_brightness';
  static const keyAutoBrightness = 'auto_brightness';
  // Notification sound
  static const keyNotificationSoundUri = 'notification_sound_uri';
  static const keyNotificationSoundTitle = 'notification_sound_title';
  // Welcome greeting
  static const keyWelcomeGreetingEnabled = 'welcome_greeting_enabled';
  // Weather
  static const keyWeatherApiKey = 'weather_api_key';
  static const keyWeatherCity = 'weather_city';
  // Vehicle tracking
  static const keyVehicleTrackingEnabled = 'vehicle_tracking_enabled';
  static const keyVehicleTrackingHistory = 'vehicle_tracking_history';
  static const keyVehicleTrackingSyncEndpoint =
      'vehicle_tracking_sync_endpoint';
  static const keyVehicleProfile = 'vehicle_profile';

  // Performance targets
  static const coldStartTargetMs = 5000;
  static const warmStartTargetMs = 2000;
  static const targetFps = 60;
  static const maxMemoryMb = 500;
}
