import 'package:car_launcher/features/vehicle/data/vehicle_api_client.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';

/// Repository for the vehicle management feature — thin mapping layer over
/// [VehicleApiClient].
class VehicleRepository {
  VehicleRepository({required this._apiClient, required this.syncEndpoint});

  final VehicleApiClient _apiClient;

  /// Endpoint override for the vehicle service base URL.
  final String syncEndpoint;

  /// List all vehicles (first page, up to 10).
  Future<List<Vehicle>> listVehicles() =>
      _apiClient.fetchVehicles(endpoint: syncEndpoint);

  /// Get a single vehicle by ID.
  Future<Vehicle> getVehicle(String id) =>
      _apiClient.getVehicle(endpoint: syncEndpoint, id: id);

  /// Create a new vehicle via POST /vehicles.
  Future<Vehicle> createVehicle(Vehicle vehicle) =>
      _apiClient.saveVehicle(endpoint: syncEndpoint, vehicle: vehicle);

  /// Update an existing vehicle via PATCH /vehicles/:id.
  Future<Vehicle> updateVehicle(String id, Vehicle vehicle) =>
      _apiClient.updateVehicle(endpoint: syncEndpoint, id: id, vehicle: vehicle);
}
