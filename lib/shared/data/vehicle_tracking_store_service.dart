import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:car_launcher/core/native/native_bridge.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'location_service.dart';

class VehicleTrackingSnapshot {
  const VehicleTrackingSnapshot({
    required this.enabled,
    required this.syncEndpoint,
    required this.vehicle,
    required this.pending,
    required this.synced,
  });

  final bool enabled;
  final String syncEndpoint;
  final VehicleProfile vehicle;
  final List<VehicleTrackPoint> pending;
  final List<VehicleTrackPoint> synced;

  List<VehicleTrackPoint> get points =>
      [...synced, ...pending]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
}

class VehicleTrackingStoreService {
  VehicleTrackingStoreService({Directory? directory, String? databasePath})
    : _directoryOverride = directory,
      _databasePathOverride = databasePath;

  static const databaseFileName = 'vehicle_tracking.sqlite';
  static const pendingTable = 'pending_points';
  static const syncedTable = 'synced_points';
  static const _maxSyncedPoints = 10000;

  final Directory? _directoryOverride;
  final String? _databasePathOverride;
  Database? _database;
  Future<void> _queue = Future<void>.value();

  Future<VehicleTrackingSnapshot> load() async {
    await _queue;
    final prefs = await SharedPreferences.getInstance();
    final db = await _db;
    final pendingRows = await db.query(pendingTable, orderBy: 'timestamp ASC');
    final syncedRows = await db.query(syncedTable, orderBy: 'timestamp ASC');
    return VehicleTrackingSnapshot(
      enabled: prefs.getBool(AppConstants.keyVehicleTrackingEnabled) ?? false,
      syncEndpoint:
          prefs.getString(AppConstants.keyVehicleTrackingSyncEndpoint) ?? '',
      vehicle: _readVehicleProfile(prefs),
      pending: pendingRows.map(_pointFromPendingRow).toList(growable: false),
      synced: syncedRows.map(_pointFromSyncedRow).toList(growable: false),
    );
  }

  Future<void> saveSettings({
    required bool enabled,
    required String syncEndpoint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyVehicleTrackingEnabled, enabled);
    await prefs.setString(
      AppConstants.keyVehicleTrackingSyncEndpoint,
      syncEndpoint,
    );
  }

  Future<void> saveVehicleProfile(VehicleProfile vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyVehicleProfile,
      jsonEncode(vehicle.toJson()),
    );
  }

  Future<void> appendPending(VehicleTrackPoint point) {
    return _enqueue(() async {
      await (await _db).insert(
        pendingTable,
        _pendingRow(point),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<List<VehicleTrackPoint>> readPending() async {
    await _queue;
    final rows = await (await _db).query(
      pendingTable,
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pointFromPendingRow).toList(growable: false);
  }

  Future<void> markSynced(Set<String> ids, DateTime syncedAt) {
    return _enqueue(() async {
      if (ids.isEmpty) return;
      final db = await _db;
      await db.transaction((txn) async {
        final moved = <VehicleTrackPoint>[];
        for (final chunk in _chunks(ids.toList(growable: false), 500)) {
          final placeholders = List.filled(chunk.length, '?').join(',');
          final rows = await txn.query(
            pendingTable,
            where: 'id IN ($placeholders)',
            whereArgs: chunk,
          );
          moved.addAll(rows.map(_pointFromPendingRow));
        }

        for (final point in moved) {
          await txn.insert(
            syncedTable,
            _syncedRow(point.markSynced(syncedAt)),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        for (final chunk in _chunks(ids.toList(growable: false), 500)) {
          final placeholders = List.filled(chunk.length, '?').join(',');
          await txn.delete(
            pendingTable,
            where: 'id IN ($placeholders)',
            whereArgs: chunk,
          );
        }

        await _trimSynced(txn);
      });
    });
  }

  Future<void> clear() {
    return _enqueue(() async {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.delete(pendingTable);
        await txn.delete(syncedTable);
      });
    });
  }

  Future<void> close() async {
    await _queue;
    final db = _database;
    _database = null;
    await db?.close();
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path = await _databasePath;
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onOpen: (db) async {
        await _createSchema(db);
      },
    );
    return _database!;
  }

  Future<String> get _databasePath async {
    final databasePathOverride = _databasePathOverride;
    if (databasePathOverride != null) return databasePathOverride;
    final directoryOverride = _directoryOverride;
    if (directoryOverride != null) {
      if (!await directoryOverride.exists()) {
        await directoryOverride.create(recursive: true);
      }
      return '${directoryOverride.path}${Platform.pathSeparator}$databaseFileName';
    }

    try {
      final nativePath = await NativeBridge.call<String>(
        'getVehicleTrackingDatabasePath',
      );
      if (nativePath != null && nativePath.isNotEmpty) return nativePath;
    } catch (_) {
      // Tests and non-Android platforms use the documents directory fallback.
    }

    final base = await getApplicationDocumentsDirectory();
    return '${base.path}${Platform.pathSeparator}$databaseFileName';
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $pendingTable (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        display_name TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $syncedTable (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        display_name TEXT NOT NULL DEFAULT '',
        timestamp TEXT NOT NULL,
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pending_timestamp ON $pendingTable(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_synced_timestamp ON $syncedTable(timestamp)',
    );
  }

  static VehicleProfile _readVehicleProfile(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.keyVehicleProfile);
    if (raw == null || raw.isEmpty) return const VehicleProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return VehicleProfile.fromJson(decoded);
      }
    } catch (_) {
      return const VehicleProfile();
    }
    return const VehicleProfile();
  }

  static Future<void> _trimSynced(Transaction txn) async {
    final count =
        Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM $syncedTable'),
        ) ??
        0;
    final excess = count - _maxSyncedPoints;
    if (excess <= 0) return;
    await txn.rawDelete(
      '''
      DELETE FROM $syncedTable
      WHERE id IN (
        SELECT id FROM $syncedTable
        ORDER BY timestamp ASC
        LIMIT ?
      )
      ''',
      [excess],
    );
  }

  static Map<String, Object?> _pendingRow(VehicleTrackPoint point) => {
    'id': point.id,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'display_name': point.displayName,
    'timestamp': point.timestamp.toUtc().toIso8601String(),
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };

  static Map<String, Object?> _syncedRow(VehicleTrackPoint point) => {
    'id': point.id,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'display_name': point.displayName,
    'timestamp': point.timestamp.toUtc().toIso8601String(),
    'synced_at': (point.syncedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  static VehicleTrackPoint _pointFromPendingRow(Map<String, Object?> row) {
    return VehicleTrackPoint(
      id: row['id'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      displayName: row['display_name'] as String? ?? '',
      timestamp: DateTime.parse(row['timestamp'] as String),
    );
  }

  static VehicleTrackPoint _pointFromSyncedRow(Map<String, Object?> row) {
    return VehicleTrackPoint(
      id: row['id'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      displayName: row['display_name'] as String? ?? '',
      timestamp: DateTime.parse(row['timestamp'] as String),
      syncedAt: DateTime.parse(row['synced_at'] as String),
    );
  }

  static Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    for (var index = 0; index < values.length; index += size) {
      yield values.sublist(
        index,
        index + size > values.length ? values.length : index + size,
      );
    }
  }
}
