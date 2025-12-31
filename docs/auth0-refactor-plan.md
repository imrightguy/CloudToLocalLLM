# Auth0 Refactor Plan for CloudToLocalLLM

## Analysis Summary
Current Supabase auth (`lib/auth/providers/supabase_auth_provider.dart` 76 LOC):
- Black-box SDK reliance, vendor lock-in, unimplemented login (line 49).
- Race conditions in auth listener (lines 15-22), null handling gaps (lines 63-70).
- Duplicated streams (StreamController lines 11,27), no secure storage/refresh explicit.
- Perf: unnecessary subscriptions; security: session risks without custom control.

Target: Fresh Auth0 PKCE/OIDC flow, no data migration, remove Supabase deps, 50% LOC reduction, stateless backend JWT validation.

## High-level Architecture (Mermaid)
```mermaid
flowchart TD
  A[Flutter Login Button] --> B[Auth0.webAuthentication.login PKCE]
  B --> C[Credentials: access/id/refresh tokens]
  C --> D[flutter_secure_storage: access_token/id_token/refresh_token/user_profile]
  D --> E[rxdart BehaviorSubject<AuthState>.add(AuthState.authenticated)]
  E --> F[AuthService.notifyListeners]
  G[Dio Interceptor] --> H[Bearer access_token on /api/*]
  H --> I[Backend express-jwt + jwks-rsa validate sig/exp/iss/aud]
  J[Token expiry detect] --> K[mutex.protect refresh: Auth0 SDK or /oauth/token]
  L[Logout Button] --> M[storage.deleteAll + Auth0.logout + BehaviorSubject.add(unauthenticated)]
```

## File Changes & Todos
- Update [`pubspec.yaml`](pubspec.yaml): remove supabase_flutter, add mutex: ^3.0.1 (deps), dio-interceptors if needed.
- Replace [`lib/auth/providers/supabase_auth_provider.dart`](lib/auth/providers/supabase_auth_provider.dart) with auth0_auth_provider.dart (<40 LOC).
- Update [`lib/services/auth_service.dart`](lib/services/auth_service.dart): inject Auth0Provider.
- New [`lib/services/api_service.dart`](lib/services/api_service.dart): Dio with auth interceptor.
- Backend: [`server/routes/protected.js`](server/routes/protected.js) express-jwt/JWKS.
- Update [`lib/main.dart`](lib/main.dart), [`lib/screens/login_screen.dart`](lib/screens/login_screen.dart).
- Tests: [`test/auth0_auth_provider_test.dart`](test/auth0_auth_provider_test.dart).
- Remove Supabase files/config.

## Risks & Mitigations
- Auth0 costs: Monitor dashboard, fallback custom auth flag.
- Races: Mutex on login/refresh.
- Token leaks: HTTPS, no logs, secure_storage.
- Stateless scale: Redis blacklist for refresh rotation if >1k RPS.

## References
- [auth0-flutter-samples](https://github.com/auth0/auth0-flutter-samples)
- [flutter-auth0-dio-interceptor](https://github.com/search?q=flutter+auth0+dio+interceptor)
- [auth0-express-webapi](https://github.com/auth0/express-jwt-samples)
- OWASP JWT Cheat Sheet.

## Verification
1. flutter pub get && dart analyze
2. flutter test --coverage >90%
3. flutter run -- login → inspect storage → API 200 → logout → guard.
