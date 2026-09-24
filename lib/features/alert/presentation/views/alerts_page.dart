import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:car_launcher/features/alert/domain/alert_rule.dart';
import 'package:car_launcher/features/alert/domain/vehicle_alert.dart';
import 'package:car_launcher/features/alert/presentation/providers/alert_providers.dart';
import 'package:car_launcher/features/alert/presentation/widgets/alert_rule_form_dialog.dart';
import 'package:car_launcher/shared/widgets/car_feature_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Page at `/vehicles/:id/alerts` — raised speeding / idle alerts plus the
/// rules that produce them.
class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(
      accountSessionProvider.select((s) => s.valueOrNull != null),
    );
    if (!isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: LoginRequiredWidget(featureLabel: 'Alerts'),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: context.palette.background,
          title: Text(
            'Alerts',
            style: TextStyle(color: context.palette.textPrimary, fontSize: 22),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.palette.textPrimary),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            indicatorColor: context.palette.accent,
            labelColor: context.palette.textPrimary,
            unselectedLabelColor: context.palette.textSecondary,
            tabs: [Tab(text: 'Raised'), Tab(text: 'Rules')],
          ),
        ),
        body: TabBarView(
          children: [
            _RaisedAlertsTab(vehicleId: vehicleId),
            _AlertRulesTab(vehicleId: vehicleId),
          ],
        ),
      ),
    );
  }
}

class _RaisedAlertsTab extends ConsumerStatefulWidget {
  const _RaisedAlertsTab({required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<_RaisedAlertsTab> createState() => _RaisedAlertsTabState();
}

class _RaisedAlertsTabState extends ConsumerState<_RaisedAlertsTab> {
  AlertStatus? _status = AlertStatus.open;

  @override
  Widget build(BuildContext context) {
    final query = (
      vehicleId: widget.vehicleId,
      type: null,
      status: _status,
    );
    final alertsAsync = ref.watch(alertListProvider(query));

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chip('Open', AlertStatus.open),
                _chip('Resolved', AlertStatus.resolved),
                _chip('All', null),
              ],
            ),
          ),
        ),
        Expanded(
          child: alertsAsync.when(
            loading: () => const VehicleLoadingView(),
            error: (error, _) => VehicleErrorView(
              message: 'Failed to load alerts',
              detail: error.toString(),
              onRetry: () => ref.invalidate(alertListProvider(query)),
            ),
            data: (alerts) => alerts.isEmpty
                ? const VehicleEmptyView(
                    icon: Icons.notifications_none,
                    message: 'No alerts here',
                  )
                : RefreshIndicator(
                    color: context.palette.accent,
                    onRefresh: () =>
                        ref.read(alertListProvider(query).notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: alerts.length,
                      itemBuilder: (context, i) => _AlertTile(
                        alert: alerts[i],
                        onResolve: alerts[i].isOpen
                            ? () => _resolve(query, alerts[i])
                            : null,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, AlertStatus? value) {
    final active = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _status = value),
        selectedColor: context.palette.accent.withValues(alpha: 0.25),
        backgroundColor: context.palette.surfaceRaised,
        labelStyle: TextStyle(
          color: active ? context.palette.textPrimary : context.palette.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _resolve(AlertQuery query, VehicleAlert alert) async {
    try {
      await ref.read(alertListProvider(query).notifier).resolve(alert.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve alert: $e')),
        );
      }
    }
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, this.onResolve});

  final VehicleAlert alert;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final color = alert.type == AlertType.overspeed
        ? context.palette.danger
        : context.palette.warning;
    final peak = alert.peakValue == null
        ? null
        : alert.type == AlertType.overspeed
            ? '${alert.peakValue!.toStringAsFixed(0)} km/h'
            : '${alert.peakValue!.toStringAsFixed(0)} min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  alert.type == AlertType.overspeed
                      ? Icons.speed
                      : Icons.timelapse,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  alert.type.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  alert.isOpen ? 'OPEN' : 'RESOLVED',
                  style: TextStyle(
                    color: alert.isOpen
                        ? context.palette.warning
                        : context.palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.message.isEmpty ? '—' : alert.message,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                formatVehicleTimestamp(alert.startedAt),
                if (peak != null) 'peak $peak',
              ].join('  ·  '),
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
            if (onResolve != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Resolve'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertRulesTab extends ConsumerWidget {
  const _AlertRulesTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(alertRuleListProvider(vehicleId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'alert-rule-add',
        backgroundColor: context.palette.accent,
        onPressed: () => _openForm(context, ref, null),
        child: Icon(Icons.add, color: context.palette.onAccent),
      ),
      body: rulesAsync.when(
        loading: () => const VehicleLoadingView(),
        error: (error, _) => VehicleErrorView(
          message: 'Failed to load rules',
          detail: error.toString(),
          onRetry: () => ref.invalidate(alertRuleListProvider(vehicleId)),
        ),
        data: (rules) => rules.isEmpty
            ? const VehicleEmptyView(
                icon: Icons.rule,
                message: 'No alert rules yet.\nTap + to add one.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: rules.length,
                itemBuilder: (context, i) => _RuleTile(
                  rule: rules[i],
                  onEdit: () => _openForm(context, ref, rules[i]),
                  onDelete: () => _delete(context, ref, rules[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    AlertRule? rule,
  ) async {
    final result = await showDialog<AlertRule?>(
      context: context,
      builder: (_) => AlertRuleFormDialog(
        rule: rule,
        vehicleId: vehicleId.isEmpty ? null : vehicleId,
      ),
    );
    if (result == null || !context.mounted) return;
    final notifier = ref.read(alertRuleListProvider(vehicleId).notifier);
    try {
      if (rule == null) {
        await notifier.createRule(result);
      } else {
        await notifier.updateRule(result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rule: $e')),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AlertRule rule,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: Text(
          'Delete rule?',
          style: TextStyle(color: context.palette.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(alertRuleListProvider(vehicleId).notifier).deleteRule(rule.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete rule: $e')),
        );
      }
    }
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  final AlertRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final detail = rule.isOverspeed
        ? '> ${rule.speedLimitKph?.toStringAsFixed(0) ?? '?'} km/h'
            '${(rule.minDurationSeconds ?? 0) > 0 ? ' for ${rule.minDurationSeconds}s' : ''}'
        : 'idle ≥ ${rule.idleMinutes ?? '?'} min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              rule.isOverspeed ? Icons.speed : Icons.timelapse,
              color: rule.active
                  ? context.palette.accent
                  : context.palette.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rule.type.label}${rule.active ? '' : ' (inactive)'}',
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: context.palette.textSecondary,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: context.palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
