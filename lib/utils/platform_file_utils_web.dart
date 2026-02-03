// Web stub implementation for file utilities
import 'package:flutter/foundation.dart';

class PlatformFileUtils {
  static Future<void> writeCallbackFile(String callbackUrl) async {
    // No-op on web - callback handling is different
    debugPrint('[PlatformFileUtils] Web platform - callback file not needed');
  }
}
