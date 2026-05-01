# Voice Interface Implementation

> Status: superseded planning note.
>
> Current product direction folds voice into the avatar companion sidecar. The current implementation lives in `lib/services/voice/`, `lib/widgets/voice/`, and the local `/v1/audio/speech` router endpoint. Do not treat the backend `/api/v1/voice/transcribe` and `/api/v1/voice/synthesize` plan below as current architecture unless a task explicitly revives it.

## Overview

This document describes the implementation of a voice interface for CloudToLocalLLM, enabling speech-to-text (STT), text-to-speech (TTS), and voice-driven conversations with LLMs.

**Validates: Requirements TBD**

## Components Implemented

### 1. Backend: Speech-to-Text Service (STT)

Uses OpenAI Whisper CLI for local speech recognition.

#### Installation Requirements

- **Whisper CLI:** `whisper` command available on system
- **Models:** Downloaded on first run to `~/.cache/whisper`
- **Supported models:** `tiny`, `base`, `small`, `medium`, `large-v3`

#### STT Service (`services/api-backend/lib/services/stt-service.js`)

Core service for transcribing audio:

```javascript
class STTService {
  /**
   * Transcribe audio file to text
   * @param {string} audioPath - Path to audio file
   * @param {object} options - Transcription options
   * @returns {Promise<string>} - Transcribed text
   */
  async transcribe(audioPath, options = {}) {
    const {
      model = 'base',      // default model (tiny/base/small/medium/large-v3)
      language = 'auto',    // auto-detect or specify (en, fr, etc.)
      task = 'transcribe',  // transcribe or translate
      format = 'txt'        // txt, json, srt, vtt
    } = options;

    const args = [
      audioPath,
      '--model', model,
      '--language', language,
      '--task', task,
      '--output_format', format,
      '--output_dir', '/tmp/whisper-output',
      '--verbose', 'False'
    ];

    // Execute whisper CLI
    const result = await execAsync('whisper', args);
    return result.stdout.trim();
  }

  /**
   * Get available models
   * @returns {Array<string>} - Available model names
   */
  getAvailableModels() {
    return ['tiny', 'base', 'small', 'medium', 'large-v3'];
  }
}
```

#### API Endpoints

```
POST /api/v1/voice/transcribe
Body: {
  audio: File (multipart/form-data),
  options?: {
    model: string,
    language: string,
    format: string
  }
}
Response: {
  text: string,
  duration: number,
  model: string,
  processingTime: number
}
```

### 2. Backend: Text-to-Speech Service (TTS)

Uses OpenClaw TTS tool integration for generating audio from text.

#### TTS Service (`services/api-backend/lib/services/tts-service.js`)

```javascript
class TTSService {
  /**
   * Convert text to speech
   * @param {string} text - Text to synthesize
   * @param {object} options - TTS options
   * @returns {Promise<Buffer>} - Audio data
   */
  async synthesize(text, options = {}) {
    const {
      voice = 'default',
      speed = 1.0,
      pitch = 1.0
    } = options;

    // Use OpenClaw tts tool via internal API
    const audioData = await callTTSAPI(text, {
      voice, speed, pitch
    });

    return Buffer.from(audioData, 'base64');
  }
}
```

#### API Endpoints

```
POST /api/v1/voice/synthesize
Body: {
  text: string,
  options?: {
    voice: string,
    speed: number,
    pitch: number
  }
}
Response: {
  audio: string (base64),
  duration: number,
  voice: string
}
```

### 3. Frontend: Voice Conversation Widget

Flutter widget for voice-driven conversations.

#### Voice Conversation Screen (`lib/widgets/voice_conversation_screen.dart`)

```dart
class VoiceConversationScreen extends StatefulWidget {
  @override
  State<VoiceConversationScreen> createState() => _VoiceConversationScreenState();
}

class _VoiceConversationScreenState extends State<VoiceConversationScreen> {
  bool isRecording = false;
  bool isProcessing = false;
  String transcript = '';
  String response = '';
  Timer? _silenceTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voice Mode')),
      body: Column(
        children: [
          // Transcript display
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (transcript.isNotEmpty)
                    _buildTranscriptBubble(transcript, isUser: true),
                  if (response.isNotEmpty)
                    _buildTranscriptBubble(response, isUser: false),
                ],
              ),
            ),
          ),
          // Recording controls
          _buildRecordingControls(),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: 'record',
            onPressed: isRecording ? stopRecording : startRecording,
            backgroundColor: isRecording ? Colors.red : Colors.blue,
            child: Icon(isRecording ? Icons.stop : Icons.mic),
          ),
        ],
      ),
    );
  }
}
```

#### Audio Recording Service (`lib/services/audio_recording_service.dart`)

```dart
class AudioRecordingService {
  final _audioRecorder = Record();

  Future<bool> startRecording({
    String path = '/tmp/voice_input.wav',
    int sampleRate = 16000,
    int bitRate = 128000,
  }) async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: sampleRate,
            bitRate: bitRate,
          ),
          path: path,
        );
        return true;
      }
    } catch (e) {
      print('Recording error: $e');
    }
    return false;
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path;
  }
}
```

#### Audio Playback Service (`lib/services/audio_playback_service.dart`)

```dart
class AudioPlaybackService {
  final _audioPlayer = AudioPlayer();

  Future<void> play(String audioPath) async {
    await _audioPlayer.play(DeviceFileSource(audioPath));
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
```

### 4. Voice Activity Detection (VAD)

Silence detection to automatically stop recording.

```dart
class VoiceActivityDetector {
  Timer? _silenceTimer;
  final int silenceThresholdMs = 1500; // 1.5 seconds of silence

  void startListening(Function onSilence) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      Duration(milliseconds: silenceThresholdMs),
      () => onSilence(),
    );
  }

  void stopListening() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  void reset() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      Duration(milliseconds: silenceThresholdMs),
      () {},
    );
  }
}
```

## Configuration

### User Voice Settings

```sql
-- Database schema
CREATE TABLE user_voice_settings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  stt_model VARCHAR(50) DEFAULT 'base',
  stt_language VARCHAR(10) DEFAULT 'en',
  tts_voice VARCHAR(100) DEFAULT 'default',
  tts_speed DECIMAL(3,2) DEFAULT 1.00,
  tts_pitch DECIMAL(3,2) DEFAULT 1.00,
  silence_threshold_ms INTEGER DEFAULT 1500,
  wake_word_enabled BOOLEAN DEFAULT false,
  wake_word VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Settings UI Widget

```dart
class VoiceSettingsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: Text('STT Model'),
          subtitle: DropdownButton<String>(
            value: selectedModel,
            items: ['tiny', 'base', 'small', 'medium']
                .map((model) => DropdownMenuItem(
                      value: model,
                      child: Text(model),
                    ))
                .toList(),
            onChanged: (value) => updateSTTModel(value),
          ),
        ),
        ListTile(
          title: Text('TTS Voice'),
          subtitle: DropdownButton<Voice>(
            value: selectedVoice,
            items: availableVoices
                .map((voice) => DropdownMenuItem(
                      value: voice,
                      child: Text(voice.name),
                    ))
                .toList(),
            onChanged: (value) => updateTTSVoice(value),
          ),
        ),
        ListTile(
          title: Text('Speech Speed'),
          subtitle: Slider(
            value: speechSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            onChanged: (value) => updateSpeechSpeed(value),
          ),
        ),
      ],
    );
  }
}
```

## API Integration

### Voice Conversation Flow

```
1. User taps microphone
2. Audio recording starts (16kHz, 128kbps)
3. User speaks, silence detected → recording stops
4. Audio uploaded to /api/v1/voice/transcribe
5. Whisper transcribes → returns text
6. Text sent to LLM → generates response
7. Response sent to /api/v1/voice/synthesize
8. TTS returns audio → plays to user
9. Ready for next input
```

### Real-time Streaming

```dart
class StreamingVoiceConversation extends StatefulWidget {
  @override
  _StreamingVoiceConversationState createState() => _StreamingVoiceConversationState();
}

class _StreamingVoiceConversationState extends State<StreamingVoiceConversation> {
  final _audioStreamer = AudioStreamer();

  void startStreaming() {
    _audioStreamer.onData = (audioChunk) {
      // Stream audio to backend for real-time STT
      _voiceService.streamTranscribe(audioChunk);
    };
  }
}
```

## Security Considerations

1. **Audio Storage:** Temporary files in `/tmp` with automatic cleanup
2. **Rate Limiting:** Prevent abuse of transcription/TTS endpoints
3. **Input Validation:** Validate file types (WAV, MP3, M4A)
4. **Size Limits:** Max 10MB per audio file
5. **Privacy:** Audio data never persisted to database

## Performance Optimization

1. **Whisper Model Selection:** 
   - `tiny`: Fastest (~0.5s), least accurate
   - `base`: Good balance (~1s), default
   - `small`: More accurate (~2s)
   - `medium/ large-v3`: Best accuracy (~4-8s)

2. **Audio Buffering:** 
   - Pre-buffer 100ms before starting recording
   - Smooth out audio input/output

3. **Caching:**
   - Cache TTS responses for repeated phrases
   - Pre-load Whisper models on app startup

## Platform Support

### Linux/Desktop
- Full support: STT (Whisper) + TTS (OpenClaw)
- System audio capture/playback

### Web
- STT: Web Speech API (browser)
- TTS: Web Speech Synthesis API
- Fallback to backend if unavailable

### Windows
- Full support: STT (Whisper) + TTS (OpenClaw)
- WASAPI audio capture/playback

## Testing

```javascript
// STT Service Tests
describe('STTService', () => {
  it('should transcribe audio file', async () => {
    const text = await sttService.transcribe('/tmp/test.wav', {
      model: 'tiny',
      language: 'en'
    });
    expect(text).toBeTruthy();
  });
});

// TTS Service Tests
describe('TTSService', () => {
  it('should synthesize text to audio', async () => {
    const audio = await ttsService.synthesize('Hello world');
    expect(audio).toBeInstanceOf(Buffer);
    expect(audio.length).toBeGreaterThan(0);
  });
});
```

## Implementation Status

- [ ] Backend STT service (Whisper integration)
- [ ] Backend TTS service (OpenClaw integration)
- [ ] API endpoints for transcribe/synthesize
- [ ] Database migration for voice settings
- [ ] Frontend audio recording service
- [ ] Frontend audio playback service
- [ ] Voice conversation widget
- [ ] Voice settings UI
- [ ] Voice activity detection
- [ ] Platform-specific implementations
- [ ] Tests for all components
- [ ] Documentation updates

## Next Steps

1. Install Whisper CLI on development systems
2. Implement STT service with CLI wrapper
3. Implement TTS service with OpenClaw integration
4. Create database migration for voice settings
5. Implement Flutter audio recording/playback
6. Build voice conversation UI
7. Add VAD for automatic recording control
8. Test on Linux, Windows, and Web platforms
9. Performance optimization and caching
10. User documentation
