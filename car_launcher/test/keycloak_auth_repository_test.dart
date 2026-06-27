import 'package:flutter_test/flutter_test.dart';
import 'package:car_launcher/features/account/domain/account_user.dart';

void main() {
  group('AccountAuthProvider', () {
    test('only has email provider', () {
      expect(AccountAuthProvider.values, equals([AccountAuthProvider.email]));
    });

    test('email provider label is correct', () {
      expect(AccountAuthProvider.email.label, equals('Email'));
    });
  });

  group('AccountUser', () {
    test('defaults to email auth provider', () {
      final user = AccountUser(
        id: 'test-id',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      expect(user.authProvider, equals(AccountAuthProvider.email));
    });

    test('initials from display name', () {
      final user = AccountUser(
        id: '1',
        email: 'test@example.com',
        displayName: 'Dai Nguyen',
      );
      expect(user.initials, equals('DN'));
    });

    test('initials from single name', () {
      final user = AccountUser(
        id: '1',
        email: 'test@example.com',
        displayName: 'Dai',
      );
      expect(user.initials, equals('D'));
    });

    test('initials from empty name', () {
      final user = AccountUser(
        id: '1',
        email: 'test@example.com',
        displayName: '',
      );
      expect(user.initials, equals('?'));
    });
  });
}
