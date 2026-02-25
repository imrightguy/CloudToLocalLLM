// Desktop implementation for file utilities
import 'dart:io';

class PlatformFileUtils {
  static Future<void> writeCallbackFile(String callbackUrl) async {
    final tempDir = Directory.systemTemp;
    final callbackFile = File('${tempDir.path}/cloudtolocalllm_callback.txt');
    await callbackFile.writeAsString(callbackUrl);
  }
}
