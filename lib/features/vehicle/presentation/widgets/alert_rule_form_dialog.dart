import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:car_launcher/features/vehicle/domain/alert_rule.dart';
import 'package:flutter/material.dart';

/// Create / edit a speeding (OVERSPEED) or idle (IDLE) alert rule.
///
/// Returns the assembled [AlertRule] on save (with [AlertRule.id] carried over
/// when editing), or `null` on cancel. Persisting is the caller's job.
class AlertRuleFormDialog extends StatefulWidget {
  const AlertRuleFormDialog({super.key, this.rule, this.vehicleId});

  final AlertRule? rule;

  /// When set, a new rule is bound to this vehicle; otherwise it is owner-wide.
  final String? vehicleId;

  @override
  State<AlertRuleFormDialog> createState() => _AlertRuleFormDialogState();
}

class _AlertRuleFormDialogState extends State<AlertRuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late AlertType _type;
  late final TextEditingController _speedCtrl;
  late final TextEditingController _minDurationCtrl;
  late final TextEditingController _idleCtrl;
  late bool _active;

  bool get _isEdit => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _type = r?.type ?? AlertType.overspeed;
    _speedCtrl =
        TextEditingController(text: r?.speedLimitKph?.toStringAsFixed(0) ?? '');
    _minDurationCtrl =
        TextEditingController(text: r?.minDurationSeconds?.toString() ?? '0');
    _idleCtrl = TextEditingController(text: r?.idleMinutes?.toString() ?? '');
    _active = r?.active ?? true;
  }

  @override
  void dispose() {
    _speedCtrl.dispose();
    _minDurationCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.rule ?? AlertRule(vehicleId: widget.vehicleId);
    final result = base.copyWith(
      type: _type,
      active: _active,
      speedLimitKph: _type == AlertType.overspeed
          ? double.tryParse(_speedCtrl.text.trim())
          : null,
      minDurationSeconds: _type == AlertType.overspeed
          ? int.tryParse(_minDurationCtrl.text.trim()) ?? 0
          : null,
      idleMinutes: _type == AlertType.idle
          ? int.tryParse(_idleCtrl.text.trim())
          : null,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CarPlayTheme.surface,
      title: Text(
        _isEdit ? 'Edit alert rule' : 'New alert rule',
        style: const TextStyle(color: CarPlayTheme.onSurface),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<AlertType>(
                segments: const [
                  ButtonSegment(
                    value: AlertType.overspeed,
                    label: Text('Speeding'),
                    icon: Icon(Icons.speed),
                  ),
                  ButtonSegment(
                    value: AlertType.idle,
                    label: Text('Idle'),
                    icon: Icon(Icons.timelapse),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: _isEdit
                    ? null
                    : (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              if (_type == AlertType.overspeed) ...[
                TextFormField(
                  controller: _speedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Speed limit (km/h)',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'Enter a speed ≥ 1';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _minDurationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sustain for (seconds), 0 = immediate',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Enter 0 or more';
                    return null;
                  },
                ),
              ] else
                TextFormField(
                  controller: _idleCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Idle minutes',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'Enter 1 or more';
                    return null;
                  },
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Active',
                  style: TextStyle(color: CarPlayTheme.onSurface, fontSize: 14),
                ),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
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
}
