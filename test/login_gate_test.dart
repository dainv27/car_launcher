import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/account/presentation/widgets/login_required.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginRequiredWidget', () {
    testWidgets('renders glass panel with sign-in required message',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginRequiredWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
      expect(
        find.text('Sign in to manage your vehicles and tracking.'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('tapping Sign In navigates to /login', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: LoginRequiredWidget()),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('Login Page')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);
    });

    testWidgets('rends custom feature label when provided', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginRequiredWidget(featureLabel: 'Manage vehicles'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage vehicles'), findsOneWidget);
      expect(find.text('Sign in required'), findsOneWidget);
    });
  });

  group('_gate logic — isLoggedIn helper', () {
    testWidgets('unauthenticated user sees gate', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionProvider.overrideWith(() => _NullUserNotifier()),
          ],
          child: MaterialApp(
            home: _GateTestScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
    });

    testWidgets('authenticated user sees normal UI', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionProvider.overrideWith(
              () => _StubUserNotifier(
                const AccountUser(
                  id: 'u-1',
                  email: 'test@example.com',
                  displayName: 'Tester',
                  preferredLocale: 'vi',
                  authProvider: AccountAuthProvider.email,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: _GateTestScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal UI'), findsOneWidget);
      expect(find.text('Sign in required'), findsNothing);
    });
  });
}

/// A tiny harness that watches [accountSessionProvider]
/// and renders the gate when the user is not signed in.
class _GateTestScaffold extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn =
        ref.watch(accountSessionProvider.select((s) => s.valueOrNull != null));

    if (!isLoggedIn) {
      return const Scaffold(body: LoginRequiredWidget());
    }
    return const Scaffold(body: Text('Normal UI'));
  }
}

class _NullUserNotifier extends AccountNotifier {
  @override
  Future<AccountUser?> build() async => null;
}

class _StubUserNotifier extends AccountNotifier {
  _StubUserNotifier(this._user);

  final AccountUser _user;

  @override
  Future<AccountUser?> build() async => _user;
}
