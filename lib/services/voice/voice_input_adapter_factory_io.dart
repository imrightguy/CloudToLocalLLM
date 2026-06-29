import 'dart:io';

import 'dev_voice_input_adapter.dart';
import 'linux_voice_input_adapter_io.dart';
import 'voice_input_types.dart';
import 'windows_voice_input_adapter.dart';

VoiceInputAdapter createDefaultVoiceInputAdapter() {
  if (Platform.isWindows) {
    return WindowsVoiceInputAdapter();
  }
  if (Platform.isLinux) {
    return LinuxVoiceInputAdapter();
  }
  return DevVoiceInputAdapter();
}
