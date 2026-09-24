/// A coordinate resolved to a human-readable address.
///
/// Mirrors `ReverseGeocodeResponse` in the vehicle-service client API. The
/// backing provider is operator-configured; when it is not set the endpoint
/// answers `503` and the app should treat the address as simply unavailable.
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.displayName,
    this.latitude,
    this.longitude,
  });

  final String displayName;
  final double? latitude;
  final double? longitude;

  bool get hasName => displayName.trim().isNotEmpty;

  factory ReverseGeocodeResult.fromJson(Map<String, dynamic> json) {
    return ReverseGeocodeResult(
      displayName: json['displayName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
