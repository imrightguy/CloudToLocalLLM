import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'token_storage_service.dart';

/// Service for interacting with the Gmail API.
/// Allows users to connect multiple Gmail accounts and search/read messages.
class GmailService extends ChangeNotifier {
  final AuthService _authService;
  final TokenStorageService _tokenStorage;
  final Dio _dio;

  // State
  bool _isLoading = false;
  String? _error;
  List<String> _connectedAccounts = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get connectedAccounts => _connectedAccounts;

  GmailService({
    required AuthService authService,
    required TokenStorageService tokenStorage,
    Dio? dio,
  })  : _authService = authService,
        _tokenStorage = tokenStorage,
        _dio = dio ?? Dio() {
    _loadConnectedAccounts();
  }

  /// Load connected Gmail accounts from storage
  Future<void> _loadConnectedAccounts() async {
    // Logic to retrieve list of accounts from token storage
    // For now, this is a stub
    _connectedAccounts = []; 
    notifyListeners();
  }

  /// Start the OAuth flow for a Gmail account
  Future<void> connectAccount() async {
    _setLoading(true);
    try {
      // 1. Trigger OAuth flow (similar to AdminCenterService)
      // 2. Capture tokens
      // 3. Store tokens in _tokenStorage
      // 4. Update _connectedAccounts
      _setError(null);
    } catch (e) {
      _setError('Failed to connect Gmail account: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Search messages in a specific Gmail account
  Future<List<Map<String, dynamic>>> searchMessages(String email, String query, {int limit = 10}) async {
    _setLoading(true);
    try {
      // 1. Get access token for this email from storage
      // 2. Call Gmail API search endpoint
      // 3. Return mapped results
      return [];
    } catch (e) {
      _setError('Failed to search messages: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
