import 'auth_provider.dart';
import 'providers/auth0_auth_provider.dart';

/// Factory for creating the configured authentication provider
class AuthProviderFactory {
  /// Create the authentication provider based on the application configuration
  static AuthProvider create() => Auth0AuthProvider();
}
