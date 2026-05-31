import 'dart:io';

import 'dev_voice_input_adapter.dart';
import 'linux_voice_input_adapter_io.dart';
import 'voice_input_types.dart';

VoiceInputAdapter createDefaultVoiceInputAdapter() {
  return Platform.isLinux ? LinuxVoiceInputAdapter() : DevVoiceInputAdapter();
}
