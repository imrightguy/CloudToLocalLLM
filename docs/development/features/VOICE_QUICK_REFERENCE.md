# Voice Interface Quick Reference

> Status: superseded planning note.
>
> Voice now belongs to the avatar companion. Current code uses `lib/services/voice/`, `lib/widgets/voice/`, Hermes bridge status files, and the local `/v1/audio/speech` endpoint. The backend `/api/v1/voice/*` endpoints below are historical planning details, not current product direction.

## Overview
Voice interface for CloudToLocalLLM: Speech-to-Text (STT) and Text-to-Speech (TTS) integration.

## Installation

### Whisper CLI (STT)
```bash
# Install Whisper (using openai-whisper skill)
whisper --help

# Download models on first use
whisper audio.wav --model base

# Available models
tiny, base, small, medium, large-v3
```

## API Endpoints

### Transcribe Audio (STT)
```bash
POST /api/v1/voice/transcribe
Content-Type: multipart/form-data

Body:
- audio: File (WAV, MP3, M4A)
- options.model: "base" (default: base)
- options.language: "en" (default: auto)
- options.format: "txt" (default: txt)

Response:
{
  "text": "Transcribed text here",
  "duration": 3.2,
  "model": "base",
  "processingTime": 0.85
}
```

### Synthesize Speech (TTS)
```bash
POST /api/v1/voice/synthesize
Content-Type: application/json

Body:
{
  "text": "Hello world",
  "options": {
    "voice": "default",
    "speed": 1.0,
    "pitch": 1.0
  }
}

Response:
{
  "audio": "base64-encoded-audio-data",
  "duration": 2.1,
  "voice": "default"
}
```

## Flutter Services

### Audio Recording
```dart
import 'package:record/record.dart';

final recorder = Record();
await recorder.start(
  RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    bitRate: 128000,
  ),
  path: '/tmp/voice_input.wav',
);
final path = await recorder.stop();
```

### Audio Playback
```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();
await player.play(DeviceFileSource('/tmp/response.wav'));
await player.stop();
```

### Voice Conversation Flow
```
1. User taps microphone → recording starts
2. Silence detected (1.5s) → recording stops
3. Upload audio → POST /api/v1/voice/transcribe
4. Get text → send to LLM
5. Get response → POST /api/v1/voice/synthesize
6. Play audio → ready for next input
```

## Configuration

### User Settings (database)
```sql
user_voice_settings table:
- stt_model: VARCHAR(50) - Whisper model
- stt_language: VARCHAR(10) - Detection language
- tts_voice: VARCHAR(100) - TTS voice
- tts_speed: DECIMAL - Playback speed (0.5-2.0)
- tts_pitch: DECIMAL - Pitch adjustment (0.5-2.0)
- silence_threshold_ms: INTEGER - VAD threshold (ms)
- wake_word_enabled: BOOLEAN
- wake_word: VARCHAR(100)
```

## Whisper Models Comparison

| Model | Size | Speed | Accuracy | Use Case |
|-------|------|-------|----------|-----------|
| tiny | 39MB | ~0.5s | Low | Quick commands |
| base | 74MB | ~1s | Good | Default choice |
| small | 244MB | ~2s | Better | General use |
| medium | 769MB | ~4s | High | Important transcription |
| large-v3 | 1550MB | ~8s | Best | Accuracy critical |

## Platform Support

| Platform | STT | TTS | Notes |
|----------|-----|-----|-------|
| Linux | Whisper CLI | OpenClaw | Full support |
| Windows | Whisper CLI | OpenClaw | Full support |
| Web | Web Speech API | Web Speech API | Browser fallback |

## Security

- Max file size: 10MB
- Allowed formats: WAV, MP3, M4A
- Temporary storage: `/tmp` (auto-cleanup)
- No audio persistence in database
- Rate limiting on all endpoints

## Testing

```bash
# Test STT directly
whisper /tmp/test.wav --model base --language en

# Test voice API
curl -X POST http://localhost:3000/api/v1/voice/transcribe \
  -F "audio=@test.wav" \
  -F 'options={"model":"base","language":"en"}'
```

## Files to Modify

- `services/api-backend/lib/services/stt-service.js` - STT service
- `services/api-backend/lib/services/tts-service.js` - TTS service
- `services/api-backend/routes/voice.js` - API routes
- `lib/services/audio_recording_service.dart` - Recording
- `lib/services/audio_playback_service.dart` - Playback
- `lib/widgets/voice_conversation_screen.dart` - UI
- `docs/development/features/VOICE_INTERFACE_IMPLEMENTATION.md` - Full docs
