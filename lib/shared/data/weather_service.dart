import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_launcher/core/logging/logging.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

/// Model for weather data
class WeatherData {
  final String cityName;
  final double temperature; // in Celsius
  final String description;
  final String iconCode; // OpenWeatherMap icon code
  final int humidity; // percentage
  final double windSpeed; // m/s

  const WeatherData({
    required this.cityName,
    required this.temperature,
    required this.description,
    required this.iconCode,
    required this.humidity,
    required this.windSpeed,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['name'] ?? '',
      temperature:
          (json['main']['temp'] as num) -
          273.15, // Convert from Kelvin to Celsius
      description: json['weather'][0]['description'] ?? '',
      iconCode: json['weather'][0]['icon'] ?? '',
      humidity: json['main']['humidity'] ?? 0,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
    );
  }

  /// Returns the asset path for the weather icon (we'll use a simple mapping for now)
  String get iconAsset {
    // Map OpenWeatherMap icon codes to our asset icons (we don't have assets yet, so we'll use Icons)
    // For now, we'll return null and use Icon based on condition in widget.
    return '';
  }
}

/// Service for fetching weather data from OpenWeatherMap API
class WeatherService {
  WeatherService(this._prefs, this._client);

  final SharedPreferences _prefs;
  final http.Client _client;

  /// Fetch weather for a given city name
  Future<WeatherData?> fetchWeatherByCity(String cityName) async {
    final apiKey = _prefs.getString(AppConstants.keyWeatherApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      AppLogger.instance.w('No weather API key configured', tag: 'WEATHER');
      return null;
    }

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=$cityName&appid=$apiKey&lang=en',
    );
    try {
      AppLogger.instance.d('Fetching weather for $cityName', tag: 'WEATHER');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = WeatherData.fromJson(json);
        AppLogger.instance.i(
          'Weather: ${data.cityName} ${data.temperature.toStringAsFixed(1)}°C ${data.description}',
          tag: 'WEATHER',
        );
        return data;
      } else {
        AppLogger.instance.w(
          'Weather API error: HTTP ${response.statusCode}',
          tag: 'WEATHER',
        );
        return null;
      }
    } catch (e) {
      AppLogger.instance.e(
        'Weather fetch failed for $cityName',
        tag: 'WEATHER',
        error: e,
      );
      return null;
    }
  }

  /// Fetch weather for current location (requires latitude and longitude)
  /// We'll implement this later if needed, for now we use city.
  Future<WeatherData?> fetchWeatherByCoords(double lat, double lon) async {
    final apiKey = _prefs.getString(AppConstants.keyWeatherApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&lang=en',
    );
    try {
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WeatherData.fromJson(json);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

/// Notifier for weather data
class WeatherNotifier extends StateNotifier<AsyncValue<WeatherData?>> {
  WeatherNotifier(this._weatherService) : super(const AsyncValue.loading()) {
    _loadWeather();
  }

  final WeatherService _weatherService;
  int _requestGeneration = 0;

  Future<void> _loadWeather() async {
    final generation = ++_requestGeneration;
    await _loadWeatherForGeneration(generation);
  }

  Future<void> _loadWeatherForGeneration(int generation) async {
    if (!mounted || generation != _requestGeneration) return;
    state = const AsyncValue.loading();
    final city = _weatherService._prefs.getString(AppConstants.keyWeatherCity);
    if (city == null || city.isEmpty) {
      AppLogger.instance.w('No weather city configured', tag: 'WEATHER');
      if (mounted && generation == _requestGeneration) {
        state = const AsyncValue.data(null);
      }
      return;
    }
    final weather = await _weatherService.fetchWeatherByCity(city);
    if (mounted && generation == _requestGeneration) {
      state = AsyncValue.data(weather);
    }
  }

  Future<void> refresh() async {
    AppLogger.instance.d('Weather refresh requested', tag: 'WEATHER');
    if (!mounted) return;
    final generation = ++_requestGeneration;
    await _loadWeatherForGeneration(generation);
  }

  Future<void> refreshForCoords(double latitude, double longitude) async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    state = const AsyncValue.loading();
    final weather = await _weatherService.fetchWeatherByCoords(
      latitude,
      longitude,
    );
    if (mounted && generation == _requestGeneration) {
      state = AsyncValue.data(weather);
    }
  }

  /// Set the city for weather and refresh
  Future<void> setCity(String city) async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    await _weatherService._prefs.setString(AppConstants.keyWeatherCity, city);
    await _loadWeatherForGeneration(generation);
  }

  /// Set the API key for weather and refresh
  Future<void> setApiKey(String key) async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    await _weatherService._prefs.setString(AppConstants.keyWeatherApiKey, key);
    await _loadWeatherForGeneration(generation);
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }
}
