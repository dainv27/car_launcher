import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:car_launcher/features/account/presentation/views/account_login_page.dart';

void main() {
  group('AccountLoginPage', () {
    testWidgets('shows only Keycloak sign-in button, no form or social logins',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountLoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the Keycloak sign-in button
      expect(find.text('Sign in'), findsOneWidget);

      // Should NOT show username/password form
      expect(find.text('Username'), findsNothing);
      expect(find.text('Password'), findsNothing);

      // Should NOT show Google/Apple social login buttons
      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.text('Sign in with Apple'), findsNothing);

      // Should NOT show dividers
      expect(find.text('or continue with SSO'), findsNothing);
      expect(find.text('or'), findsNothing);

      // Should show logo and subtitle
      expect(find.text('Sign in to Car Launcher'), findsOneWidget);
      expect(find.text('Use your account to sign in'), findsOneWidget);
    });

    testWidgets('Keycloak button is tappable', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountLoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.text('Sign in');
      expect(button, findsOneWidget);

      // The button should be enabled (not busy)
      final elevatedButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Sign in'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(elevatedButton.onPressed, isNotNull);
    });
  });
}
