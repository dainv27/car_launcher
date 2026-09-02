import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/vehicle/domain/geo_point.dart';
import 'package:car_launcher/features/vehicle/domain/geofence.dart';
import 'package:flutter/material.dart';

/// Create / edit a circle or polygon geofence.
///
/// Returns the assembled [Geofence] on save (id carried over when editing),
/// or `null` on cancel. Persisting is the caller's job.
class GeofenceFormDialog extends StatefulWidget {
  const GeofenceFormDialog({super.key, this.geofence, this.vehicleId});

  final Geofence? geofence;

  /// When set, a new geofence is bound to this vehicle; otherwise owner-wide.
  final String? vehicleId;

  @override
  State<GeofenceFormDialog> createState() => _GeofenceFormDialogState();
}

class _GeofenceFormDialogState extends State<GeofenceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _centerLatCtrl;
  late final TextEditingController _centerLonCtrl;
  late final TextEditingController _radiusCtrl;
  late GeofenceShape _shape;
  late List<({TextEditingController lat, TextEditingController lon})> _vertices;
  late bool _notifyEnter;
  late bool _notifyExit;
  late bool _active;

  bool get _isEdit => widget.geofence != null;

  @override
  void initState() {
    super.initState();
    final g = widget.geofence;
    _nameCtrl = TextEditingController(text: g?.name ?? '');
    _centerLatCtrl =
        TextEditingController(text: g?.centerLat?.toStringAsFixed(6) ?? '');
    _centerLonCtrl =
        TextEditingController(text: g?.centerLon?.toStringAsFixed(6) ?? '');
    _radiusCtrl =
        TextEditingController(text: g?.radiusMeters?.toStringAsFixed(0) ?? '200');
    _shape = g?.shape ?? GeofenceShape.circle;
    _vertices = [
      for (final p in (g?.polygon ?? const <GeoPoint>[]))
        (
          lat: TextEditingController(text: p.latitude.toStringAsFixed(6)),
          lon: TextEditingController(text: p.longitude.toStringAsFixed(6)),
        ),
    ];
    if (_vertices.isEmpty) {
      _vertices = List.generate(3, (_) => _emptyVertex());
    }
    _notifyEnter = g?.notifyOnEnter ?? true;
    _notifyExit = g?.notifyOnExit ?? true;
    _active = g?.active ?? true;
  }

  ({TextEditingController lat, TextEditingController lon}) _emptyVertex() =>
      (lat: TextEditingController(), lon: TextEditingController());

  @override
  void dispose() {
    _nameCtrl.dispose();
    _centerLatCtrl.dispose();
    _centerLonCtrl.dispose();
    _radiusCtrl.dispose();
    for (final v in _vertices) {
      v.lat.dispose();
      v.lon.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    List<GeoPoint> polygon = const [];
    if (_shape == GeofenceShape.polygon) {
      polygon = [
        for (final v in _vertices)
          GeoPoint(
            double.parse(v.lat.text.trim()),
            double.parse(v.lon.text.trim()),
          ),
      ];
      if (polygon.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A polygon needs at least 3 vertices')),
        );
        return;
      }
    }

    final base = widget.geofence ?? Geofence(vehicleId: widget.vehicleId);
    final result = base.copyWith(
      name: _nameCtrl.text.trim(),
      shape: _shape,
      centerLat: _shape == GeofenceShape.circle
          ? double.tryParse(_centerLatCtrl.text.trim())
          : null,
      centerLon: _shape == GeofenceShape.circle
          ? double.tryParse(_centerLonCtrl.text.trim())
          : null,
      radiusMeters: _shape == GeofenceShape.circle
          ? double.tryParse(_radiusCtrl.text.trim())
          : null,
      polygon: polygon,
      notifyOnEnter: _notifyEnter,
      notifyOnExit: _notifyExit,
      active: _active,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CarPlayTheme.surface,
      title: Text(
        _isEdit ? 'Edit geofence' : 'New geofence',
        style: const TextStyle(color: CarPlayTheme.onSurface),
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                SegmentedButton<GeofenceShape>(
                  segments: const [
                    ButtonSegment(
                      value: GeofenceShape.circle,
                      label: Text('Circle'),
                      icon: Icon(Icons.circle_outlined),
                    ),
                    ButtonSegment(
                      value: GeofenceShape.polygon,
                      label: Text('Polygon'),
                      icon: Icon(Icons.pentagon_outlined),
                    ),
                  ],
                  selected: {_shape},
                  onSelectionChanged: _isEdit
                      ? null
                      : (s) => setState(() => _shape = s.first),
                ),
                const SizedBox(height: 12),
                if (_shape == GeofenceShape.circle) ...[
                  _numberField(_centerLatCtrl, 'Center latitude', -90, 90),
                  const SizedBox(height: 8),
                  _numberField(_centerLonCtrl, 'Center longitude', -180, 180),
                  const SizedBox(height: 8),
                  _numberField(_radiusCtrl, 'Radius (m)', 1, 1000000),
                ] else
                  _polygonEditor(),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notify on enter',
                      style: TextStyle(
                          color: CarPlayTheme.onSurface, fontSize: 14)),
                  value: _notifyEnter,
                  onChanged: (v) => setState(() => _notifyEnter = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notify on exit',
                      style: TextStyle(
                          color: CarPlayTheme.onSurface, fontSize: 14)),
                  value: _notifyExit,
                  onChanged: (v) => setState(() => _notifyExit = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active',
                      style: TextStyle(
                          color: CarPlayTheme.onSurface, fontSize: 14)),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    double min,
    double max,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final n = double.tryParse((v ?? '').trim());
        if (n == null) return 'Enter a number';
        if (n < min || n > max) return 'Must be between $min and $max';
        return null;
      },
    );
  }

  Widget _polygonEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Vertices (ordered)',
            style: TextStyle(color: CarPlayTheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        for (var i = 0; i < _vertices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _numberField(_vertices[i].lat, 'Lat ${i + 1}', -90, 90),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(
                      _vertices[i].lon, 'Lon ${i + 1}', -180, 180),
                ),
                IconButton(
                  onPressed: _vertices.length <= 3
                      ? null
                      : () => setState(() {
                            _vertices[i].lat.dispose();
                            _vertices[i].lon.dispose();
                            _vertices.removeAt(i);
                          }),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _vertices.add(_emptyVertex())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add vertex'),
          ),
        ),
      ],
    );
  }
}
