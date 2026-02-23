---
name: vision-automation
description: Vision system development with OCR, screen analysis, camera input, and continuous monitoring templates for CloudToLocalLLM (Pillar 5)
user-invocable: true
---

# Vision Automation Development

Vision system templates for CloudToLocalLLM's Vision pillar (Pillar 5).

## Context

Vision capabilities include:
- **Screen Capture & Analysis** - Screenshot with AI-powered analysis
- **OCR** - Text extraction from screens and images
- **Camera Input** - Webcam integration for video analysis
- **Continuous Monitoring** - Periodic screen analysis
- **Region Capture** - Specific area analysis

## Quick Start

### Analyze Screen
```bash
curl -X POST http://localhost:1337/vision/analyze \
  -F "screenshot=@/path/to/screenshot.png" \
  -F "prompt=Describe what you see"
```

### Extract Text (OCR)
```bash
curl -X POST http://localhost:1337/vision/ocr \
  -F "image=@/path/to/image.png"
```

## Templates

### Screen Analysis Template
```dart
import 'package:cloudtolocalllm/services/gui_automation_service.dart';
import 'package:cloudtolocalllm/services/vision_service.dart';

/// Analyze screen content with AI
Future<void> analyzeScreen() async {
  final guiService = GuiAutomationService();
  final visionService = VisionService();

  // Capture screenshot
  final screenshot = await guiService.takeScreenshot();

  // Analyze with vision model
  final analysis = await visionService.analyzeImage(
    screenshot,
    prompt: 'Describe the UI elements visible on screen',
  );

  print('Screen analysis: $analysis');
}
```

### OCR Template
```dart
import 'package:cloudtolocalllm/services/vision_service.dart';

/// Extract text from image using OCR
Future<void> extractText() async {
  final visionService = VisionService();

  // Extract text from screenshot
  final text = await visionService.extractText(
    imagePath: 'screenshot.png',
  );

  print('Extracted text:\n$text');
}
```

### Continuous Monitoring Template
```dart
import 'dart:async';
import 'package:cloudtolocalllm/services/gui_automation_service.dart';
import 'package:cloudtolocalllm/services/vision_service.dart';

/// Monitor screen for changes
class ScreenMonitor {
  final guiService = GuiAutomationService();
  final visionService = VisionService();
  Timer? _timer;

  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _timer = Timer.periodic(interval, (_) async {
      final screenshot = await guiService.takeScreenshot();
      final analysis = await visionService.analyzeImage(
        screenshot,
        prompt: 'Describe any changes or alerts on screen',
      );

      if (analysis.contains('alert') || analysis.contains('error')) {
        print('⚠️  Detected: $analysis');
      }
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
  }
}
```

## Related Files
- GUI automation: `lib/services/gui_automation_service.dart`
- Vision service: `lib/services/vision_service.dart` (planned)
- GUI screen: `lib/screens/gui_automation_screen.dart`
