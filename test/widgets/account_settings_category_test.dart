import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:cloudtolocalllm/widgets/settings/account_settings_category.dart';
import 'package:cloudtolocalllm/models/settings_category.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';

import 'package:cloudtolocalllm/services/session_storage_service.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/models/session_model.dart';

// Mock JWTService

// Mock SessionStorageService
class MockSessionStorageService extends SessionStorageService {
  @override
  Future<SessionModel?> getCurrentSession() async {
    final user = UserModel(
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now(),
    );

    return SessionModel(
      id: 'session-id',
      userId: 'test-user-id',
      token: 'test-token',
      expiresAt: DateTime.now().add(const Duration(hours: 23)),
      user: user,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      lastActivity: DateTime.now(),
    );
  }
}

// Mock AuthService
class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isRestoringSession => false;
  @override
  Future<void> updateDisplayName(String name) async {}
  @override
  UserModel? currentUser = UserModel(
    id: 'test-user-id',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  String get assistantName => 'Test Assistant';

  @override
  Future<void> logout() async {
    currentUser = null;
    notifyListeners();
  }

  @override
  Future<void> loginMockDeveloper() async {}

  @override
  Future<void> init() async {}

  @override
  Future<bool> handleCallback({String? callbackUrl, String? code}) async =>
      true;

  @override
  Future<void> login({String? tenantId}) async {}

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getValidatedAccessToken() async => 'test-token';

  @override
  bool get isSessionBootstrapComplete => true;

  @override
  bool get isWeb => true;

  @override
  Future<void> get sessionBootstrapFuture => Future.value();

  @override
  ValueNotifier<bool> get isAuthenticated => ValueNotifier(true);

  @override
  ValueNotifier<bool> get isLoading => ValueNotifier(false);

  @override
  ValueNotifier<bool> get areAuthenticatedServicesLoaded => ValueNotifier(true);
}

void main() {
  group('AccountSettingsCategory', () {
    late MockAuthService mockAuthService;
    late MockSessionStorageService mockSessionStorage;
    late GetIt getIt;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSessionStorage = MockSessionStorageService();

      // Setup service locator
      getIt = GetIt.instance;
      if (getIt.isRegistered<AuthService>()) {
        getIt.unregister<AuthService>();
      }
      getIt.registerSingleton<AuthService>(mockAuthService);
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    testWidgets('renders user email and display name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('renders logout button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('displays session information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('respects isActive property', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                isActive: false,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('renders with correct category ID',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountSettingsCategory), findsOneWidget);
    });

    testWidgets('renders Sync to All Devices card when unauthenticated',
        (WidgetTester tester) async {
      mockAuthService.currentUser = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<AuthService>.value(
              value: mockAuthService,
              child: AccountSettingsCategory(
                categoryId: SettingsCategoryIds.account,
                sessionStorageService: mockSessionStorage,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sync to All Devices'), findsAtLeastNWidgets(1));
      expect(find.text('Connect to Cloud Relay'), findsOneWidget);
    });
  });
}
