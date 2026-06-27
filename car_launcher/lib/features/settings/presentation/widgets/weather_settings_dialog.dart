import 'package:car_launcher/features/dashboard/presentation/providers/weather_providers.dart';
import 'package:car_launcher/shared/data/weather_service.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

/// Dialog for configuring weather API key and city
class WeatherSettingsDialog extends ConsumerStatefulWidget {
  const WeatherSettingsDialog({super.key});

  @override
  ConsumerState<WeatherSettingsDialog> createState() =>
      _WeatherSettingsDialogState();
}

class _WeatherSettingsDialogState extends ConsumerState<WeatherSettingsDialog> {
  final _apiKeyController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isLoading = false;
  bool _apiKeyValid = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _apiKeyController.text =
        prefs.getString(AppConstants.keyWeatherApiKey) ?? '';
    _cityController.text =
        prefs.getString(AppConstants.keyWeatherCity) ?? 'Hanoi';
    _validateApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _validateApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _apiKeyValid = false);
      return;
    }

    setState(() => _isLoading = true);
    final weatherService = WeatherService(
      ref.read(sharedPreferencesProvider),
      ref.read(httpClientProvider),
    );
    final isValid = await weatherService.fetchWeatherByCity('London') != null;
    setState(() {
      _apiKeyValid = isValid;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final apiKey = _apiKeyController.text.trim();
    final city = _cityController.text.trim();

    if (apiKey.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.keyWeatherApiKey, apiKey);
    await prefs.setString(AppConstants.keyWeatherCity, city);

    // Refresh weather data
    ref.read(weatherProvider.notifier).refresh();

    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Weather settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weather Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // API Key field
            const Text(
              'OpenWeatherMap API Key',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your API key from openweathermap.org',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.key, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _apiKeyValid
                        ? Colors.greenAccent
                        : Colors.blueAccent,
                    width: 2,
                  ),
                ),
                errorText: !_apiKeyValid && _apiKeyController.text.isNotEmpty
                    ? 'Invalid API key'
                    : null,
              ),
              onChanged: (_) => _validateApiKey(),
            ),
            const SizedBox(height: 16),

            // City field
            const Text(
              'City for Weather',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Hanoi, Ho Chi Minh City, New York',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.location_city,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
