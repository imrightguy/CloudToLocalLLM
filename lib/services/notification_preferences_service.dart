import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api_service.dart';

class NotificationPreferencesService extends ChangeNotifier {
  NotificationPreferencesService._();
  static final NotificationPreferencesService instance =
      NotificationPreferencesService._();

  NotificationPreferences _prefs = const NotificationPreferences();
  bool _isLoading = false;

  NotificationPreferences get prefs => _prefs;
  bool get isLoading => _isLoading;

  Future<void> fetchPreferences() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await ApiService.instance.get('/notifications/me/preferences');
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null) {
        _prefs = NotificationPreferences.fromJson(data);
      }
    } catch (_) {
      // Keep defaults on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(NotificationPreferences newPrefs) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.instance.patch('/notifications/me/preferences', newPrefs.toJson());
      _prefs = newPrefs;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
