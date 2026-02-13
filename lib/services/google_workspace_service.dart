import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'token_storage_service.dart';

/// Service for interacting with Google Workspace (Gmail/Calendar) API locally.
/// Allows users to connect multiple Google accounts and search/read messages and events.
class GoogleWorkspaceService extends ChangeNotifier {
  final TokenStorageService _tokenStorage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      GmailApi.gmailReadonlyScope,
      cal.CalendarApi.calendarReadonlyScope,
      'https://www.googleapis.com/auth/userinfo.email',
    ],
  );

  // State
  bool _isLoading = false;
  String? _error;
  List<String> _connectedAccounts = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get connectedAccounts => _connectedAccounts;

  GoogleWorkspaceService({
    required TokenStorageService tokenStorage,
  }) : _tokenStorage = tokenStorage {
    _loadConnectedAccounts();
  }

  /// Load connected Google accounts from storage
  Future<void> _loadConnectedAccounts() async {
    _connectedAccounts =
        await _tokenStorage.getConnectedEmails('google_workspace');
    notifyListeners();
  }

  /// Start the OAuth flow for a Google account
  Future<void> connectAccount() async {
    _setLoading(true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        _setError('Sign-in cancelled');
        return;
      }

      final auth = await account.authentication;

      // Store tokens
      await _tokenStorage.saveTokens(
        provider: 'google_workspace',
        email: account.email,
        accessToken: auth.accessToken!,
        idToken: auth.idToken,
        refreshToken: null,
      );

      await _loadConnectedAccounts();
      _setError(null);
    } catch (e) {
      _setError('Failed to connect Google account: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get authenticated client for a specific account
  Future<http.Client?> _getAuthClient(String email) async {
    final accessToken =
        await _tokenStorage.getAccessToken('google_workspace', email);
    if (accessToken == null) return null;

    return authenticatedClient(
      http.Client(),
      AccessCredentials(
        AccessToken('Bearer', accessToken,
            DateTime.now().add(const Duration(hours: 1))),
        null,
        [GmailApi.gmailReadonlyScope, cal.CalendarApi.calendarReadonlyScope],
      ),
    );
  }

  /// Search unread messages in a specific Gmail account
  Future<List<Map<String, dynamic>>> getUnreadMessages(String email) async {
    _setLoading(true);
    try {
      final authClient = await _getAuthClient(email);
      if (authClient == null) {
        throw Exception('No authentication found for $email');
      }

      final gmailApi = GmailApi(authClient);
      final response = await gmailApi.users.messages
          .list('me', q: 'is:unread', maxResults: 10);

      final messages = <Map<String, dynamic>>[];
      if (response.messages != null) {
        for (final msgRef in response.messages!) {
          final fullMsg = await gmailApi.users.messages.get('me', msgRef.id!);
          messages.add({
            'id': fullMsg.id,
            'from': _getHeader(fullMsg, 'From'),
            'subject': _getHeader(fullMsg, 'Subject'),
            'snippet': fullMsg.snippet ?? '',
            'date': _getHeader(fullMsg, 'Date'),
          });
        }
      }

      return messages;
    } catch (e) {
      _setError('Failed to fetch unread messages: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Get upcoming calendar events for today
  Future<List<Map<String, dynamic>>> getTodayEvents(String email) async {
    _setLoading(true);
    try {
      final authClient = await _getAuthClient(email);
      if (authClient == null) {
        throw Exception('No authentication found for $email');
      }

      final calendarApi = cal.CalendarApi(authClient);
      final now = DateTime.now().toUtc();
      final endOfDay =
          DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc();

      final events = await calendarApi.events.list(
        'primary',
        timeMin: now,
        timeMax: endOfDay,
        singleEvents: true,
        orderBy: 'startTime',
      );

      final result = <Map<String, dynamic>>[];
      if (events.items != null) {
        for (final event in events.items!) {
          result.add({
            'id': event.id,
            'summary': event.summary ?? '(No Title)',
            'start': event.start?.dateTime ?? event.start?.date,
            'end': event.end?.dateTime ?? event.end?.date,
            'location': event.location,
          });
        }
      }

      return result;
    } catch (e) {
      _setError('Failed to fetch calendar events: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  String _getHeader(Message message, String name) {
    if (message.payload?.headers == null) return '';
    return message.payload!.headers!
            .firstWhere((h) => h.name?.toLowerCase() == name.toLowerCase(),
                orElse: () => MessagePartHeader(name: name, value: ''))
            .value ??
        '';
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
