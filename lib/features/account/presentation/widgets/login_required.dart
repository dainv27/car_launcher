import 'package:car_launcher/core/theme/carplay_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:car_launcher/core/theme/launcher_palette.dart';

/// Reusable glass-panel widget shown when a feature requires sign-in.
///
/// Used by the Vehicle, Tracking, and Settings surfaces to gate
/// access to authenticated customers.
class LoginRequiredWidget extends StatelessWidget {
  const LoginRequiredWidget({
    super.key,
    this.featureLabel,
  });

  /// Optional human-readable label for the gated feature (e.g. "Manage
  /// vehicles"). When provided it is rendered as a small eyebrow above
  /// the "Sign in required" heading.
  final String? featureLabel;

  @override
  Widget build(BuildContext context) {
    final hasLabel = featureLabel != null && featureLabel!.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CarPlayTheme.margin),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.palette.border),
            boxShadow: context.palette.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.palette.accent.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 28,
                  color: context.palette.accent,
                ),
              ),
              const SizedBox(height: 20),
              if (hasLabel) ...[
                Text(
                  featureLabel!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: context.palette.accent,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Sign in required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to manage your vehicles and tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.palette.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
