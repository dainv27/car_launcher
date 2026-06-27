/// Authenticated user (from Keycloak `sub`).
class AccountUser {
  const AccountUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.preferredLocale = 'vi',
    this.authProvider = AccountAuthProvider.email,
  });

  final String id;
  final String email;
  final String displayName;
  final String preferredLocale;
  final AccountAuthProvider authProvider;

  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  AccountUser copyWith({
    String? displayName,
    String? preferredLocale,
    AccountAuthProvider? authProvider,
  }) {
    return AccountUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}

enum AccountAuthProvider { email }

extension AccountAuthProviderLabel on AccountAuthProvider {
  String get label => switch (this) {
        AccountAuthProvider.email => 'Email',
      };
}
