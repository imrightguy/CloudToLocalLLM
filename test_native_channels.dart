#!/usr/bin/env dart

import 'dart:io';
import 'package:flutter/services.dart';

// Simple standalone test for native platform channels
void main() async {
  print('=== Testing Native Platform Channels ===\n');

  // Test GUI Automation channel
  const guiChannel = MethodChannel('cloudtolocallm/gui_automation');
  const windowChannel = MethodChannel('cloudtolocallm/window_manager');

  // Test 1: Screenshot
  print('Test 1: Taking screenshot...');
  try {
    final result = await guiChannel.invokeMethod('takeScreenshot', {
      'path': '/tmp/native_test_screenshot.ppm',
    });
    print('✓ Screenshot result: $result');
    if (result == true) {
      final file = File('/tmp/native_test_screenshot.ppm');
      if (await file.exists()) {
        final size = await file.length();
        print('  File created: $size bytes');
      }
    }
  } catch (e) {
    print('✗ Screenshot failed: $e');
  }

  // Test 2: Get Windows
  print('\nTest 2: Getting window list...');
  try {
    final result = await windowChannel.invokeMethod('getWindows');
    print('✓ Window list received: ${result?.length ?? 0} windows');
    if (result is List && result.isNotEmpty) {
      print('  First window: ${result[0]}');
    }
  } catch (e) {
    print('✗ Get windows failed: $e');
  }

  // Test 3: Keypress (safe - just space)
  print('\nTest 3: Testing keypress (space)...');
  try {
    final result = await guiChannel.invokeMethod('executeAction', {
      'action': 'keypress(space)',
    });
    print('✓ Keypress result: $result');
  } catch (e) {
    print('✗ Keypress failed: $e');
  }

  // Test 4: Mouse click (safe - just clicks)
  print('\nTest 4: Testing click at coordinates...');
  try {
    final result = await guiChannel.invokeMethod('executeAction', {
      'action': 'click(100,100)',
    });
    print('✓ Click result: $result');
  } catch (e) {
    print('✗ Click failed: $e');
  }

  print('\n=== Tests Complete ===');
}
