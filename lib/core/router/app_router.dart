import 'package:car_launcher/core/router/app_route_transition.dart';
import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/views/account_login_page.dart';
import 'package:car_launcher/features/app_drawer/presentation/app_drawer_page.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:car_launcher/features/dashboard/presentation/dashboard_page.dart';
import 'package:car_launcher/features/dashboard/presentation/splash_page.dart';
import 'package:car_launcher/features/media/presentation/media_center_page.dart';
import 'package:car_launcher/features/settings/presentation/clock_network_settings_page.dart';
import 'package:car_launcher/features/settings/presentation/log_viewer_page.dart';
import 'package:car_launcher/features/settings/presentation/settings_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/alerts_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/geofences_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/tracking_history_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/trip_detail_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/vehicle_detail_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/vehicle_trips_page.dart';
import 'package:car_launcher/features/vehicle/presentation/views/vehicles_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Routes that require an authenticated user. Any unauthenticated
/// navigation target in this set is redirected to `/login`.
const _protectedRoutes = <String>{'/vehicles', '/history', '/trips'};

/// App router configuration
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // Only redirect top-level protected routes. Sub-routes (e.g. /vehicles/:id)
      // are handled by their own page-level gate so we don't double-redirect.
      final location = state.matchedLocation;
      final isProtected = _protectedRoutes.any((r) => location == r || location.startsWith('$r/'));
      if (!isProtected) return null;

      final session = ref.read(accountSessionProvider);
      final isLoggedIn = session.valueOrNull != null;
      if (isLoggedIn) return null;

      return '/login';
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (context, state) => _transitionPage(state, const SplashPage())),
      GoRoute(path: '/', pageBuilder: (context, state) => _transitionPage(state, const DashboardPage())),
      GoRoute(path: '/apps', pageBuilder: (context, state) => _transitionPage(state, const AppDrawerPage())),
      GoRoute(path: '/media', pageBuilder: (context, state) => _transitionPage(state, const MediaCenterPage())),
      GoRoute(
        path: '/navigation',
        pageBuilder: (context, state) => _transitionPage(state, const MapPage(showYoutube: false)),
        routes: [
          GoRoute(
            path: 'youtube',
            pageBuilder: (context, state) => _transitionPage(state, const MapPage(showYoutube: true)),
          ),
        ],
      ),
      GoRoute(
        path: '/vehicles',
        pageBuilder: (context, state) => _transitionPage(state, const VehiclesPage()),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return _transitionPage(state, VehicleDetailPage(vehicleId: id));
            },
            routes: [
              GoRoute(
                path: 'trips',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return _transitionPage(state, VehicleTripsPage(vehicleId: id));
                },
              ),
              GoRoute(
                path: 'geofences',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return _transitionPage(state, GeofencesPage(vehicleId: id));
                },
              ),
              GoRoute(
                path: 'alerts',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return _transitionPage(state, AlertsPage(vehicleId: id));
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/trips/:tripId',
        pageBuilder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return _transitionPage(state, TripDetailPage(tripId: tripId));
        },
      ),
      GoRoute(
        path: '/history/:vehicleId',
        pageBuilder: (context, state) {
          final vehicleId = state.pathParameters['vehicleId'] ?? '';
          return _transitionPage(state, TrackingHistoryPage(vehicleId: vehicleId));
        },
      ),
      GoRoute(path: '/login', pageBuilder: (context, state) => _transitionPage(state, const AccountLoginPage())),
      GoRoute(
        path: '/callback',
        redirect: (context, state) {
          final uri = state.uri;
          if (uri.scheme != 'carlauncher' || uri.host != 'oauth' || uri.path != '/callback') {
            return null;
          }

          // MainActivity delivers the redirect to the pending OAuth request.
          // This route only controls what the user sees after returning.
          return '/';
        },
        pageBuilder: (context, state) => _transitionPage(state, const SizedBox.shrink()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _transitionPage(state, const SettingsPage()),
        routes: [
          GoRoute(
            path: 'account',
            pageBuilder: (context, state) => _transitionPage(state, const SettingsPage(initialCategory: 5)),
          ),
          GoRoute(
            path: 'clock-network',
            pageBuilder: (context, state) => _transitionPage(state, const ClockNetworkSettingsPage()),
          ),
          GoRoute(path: 'logs', pageBuilder: (context, state) => _transitionPage(state, const LogViewerPage())),
          GoRoute(
            path: 'vehicle',
            pageBuilder: (context, state) => _transitionPage(state, const SettingsPage(initialCategory: 7)),
          ),
          GoRoute(
            path: 'tracking',
            pageBuilder: (context, state) => _transitionPage(state, const SettingsPage(initialCategory: 8)),
          ),
        ],
      ),
    ],
  );
}

CarTransitionPage<void> _transitionPage(GoRouterState state, Widget child) {
  return CarTransitionPage<void>(key: state.pageKey, child: child);
}
