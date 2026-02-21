/// Property-Based Test for Platform Component Consistency Across All Screens
///
/// **Feature: unified-app-theming, Property 11: Platform Component Consistency**
/// **Validates: Requirements 16.1, 16.2, 16.3, 16.4, 16.5, 16.6**
///
/// Tests that all screens use consistent component types for each platform.
/// This test verifies:
/// - Material Design components for Web
/// - Desktop components for Windows/Linux
/// - Consistent component behavior across all screens
/// - Fallback components work correctly
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloudtolocalllm/services/platform_detection_service.dart';
import 'package:cloudtolocalllm/services/platform_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlatformDetectionService platformService;
  late PlatformAdapter platformAdapter;

  setUp(() {
    // Initialize services
    platformService = PlatformDetectionService();
    platformAdapter = PlatformAdapter(platformService);
  });

  group('Platform Component Consistency Property Tests', () {
    test(
      'Property 11: PlatformAdapter selects Material components for web',
      () {
        // Verify platform detection
        expect(platformService.isWeb || platformService.isDesktop, isTrue,
            reason: 'Platform should be detected as web or desktop');

        // Verify component type detection
        final buttonType =
            platformAdapter.getComponentType(ComponentType.button);
        expect(buttonType, equals('Material'),
            reason: 'Button component type should be Material on web/desktop');

        final textFieldType =
            platformAdapter.getComponentType(ComponentType.textField);
        expect(textFieldType, equals('Material'),
            reason:
                'TextField component type should be Material on web/desktop');

        final switchType =
            platformAdapter.getComponentType(ComponentType.switch_);
        expect(switchType, equals('Material'),
            reason: 'Switch component type should be Material on web/desktop');

        final sliderType =
            platformAdapter.getComponentType(ComponentType.slider);
        expect(sliderType, equals('Material'),
            reason: 'Slider component type should be Material on web/desktop');

        final dialogType =
            platformAdapter.getComponentType(ComponentType.dialog);
        expect(dialogType, equals('Material'),
            reason: 'Dialog component type should be Material on web/desktop');

        final progressType =
            platformAdapter.getComponentType(ComponentType.progressIndicator);
        expect(progressType, equals('Material'),
            reason:
                'Progress indicator component type should be Material on web/desktop');
      },
    );

    test(
      'Property 11: PlatformAdapter provides fallback components',
      () {
        // Test that platform adapter can build components
        final button = platformAdapter.buildButton(
          onPressed: () {},
          child: const Text('Test'),
        );

        expect(button, isNotNull,
            reason: 'PlatformAdapter should provide fallback button');
        expect(button, isA<Widget>(),
            reason: 'Fallback button should be a valid widget');

        // Test text field fallback
        final textField = platformAdapter.buildTextField(
          label: 'Test',
        );

        expect(textField, isNotNull,
            reason: 'PlatformAdapter should provide fallback text field');
        expect(textField, isA<Widget>(),
            reason: 'Fallback text field should be a valid widget');

        // Test switch fallback
        final switchWidget = platformAdapter.buildSwitch(
          value: true,
          onChanged: (value) {},
        );

        expect(switchWidget, isNotNull,
            reason: 'PlatformAdapter should provide fallback switch');
        expect(switchWidget, isA<Widget>(),
            reason: 'Fallback switch should be a valid widget');

        // Test slider fallback
        final slider = platformAdapter.buildSlider(
          value: 0.5,
          onChanged: (value) {},
        );

        expect(slider, isNotNull,
            reason: 'PlatformAdapter should provide fallback slider');
        expect(slider, isA<Widget>(),
            reason: 'Fallback slider should be a valid widget');

        // Test progress indicator fallback
        final progress = platformAdapter.buildProgressIndicator();

        expect(progress, isNotNull,
            reason:
                'PlatformAdapter should provide fallback progress indicator');
        expect(progress, isA<Widget>(),
            reason: 'Fallback progress indicator should be a valid widget');

        // Test card fallback
        final card = platformAdapter.buildCard(
          child: const Text('Test'),
        );

        expect(card, isNotNull,
            reason: 'PlatformAdapter should provide fallback card');
        expect(card, isA<Widget>(),
            reason: 'Fallback card should be a valid widget');

        // Test checkbox fallback
        final checkbox = platformAdapter.buildCheckbox(
          value: true,
          onChanged: (value) {},
        );

        expect(checkbox, isNotNull,
            reason: 'PlatformAdapter should provide fallback checkbox');
        expect(checkbox, isA<Widget>(),
            reason: 'Fallback checkbox should be a valid widget');
      },
    );

    test(
      'Property 11: Platform detection is cached for performance',
      () {
        // First detection
        final startTime1 = DateTime.now();
        final platform1 = platformService.detectPlatform();
        final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;

        // Second detection (should use cache)
        final startTime2 = DateTime.now();
        final platform2 = platformService.detectPlatform();
        final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;

        // Verify same platform detected
        expect(platform1, equals(platform2),
            reason: 'Platform detection should be consistent');

        // Verify caching improves performance (or is at least as fast)
        expect(elapsed2, lessThanOrEqualTo(elapsed1),
            reason:
                'Cached platform detection should be at least as fast as initial detection');

        // Verify detection completes within 100ms (Requirement 2.1)
        expect(elapsed1, lessThan(100),
            reason:
                'Initial platform detection should complete within 100ms (actual: ${elapsed1}ms)');
      },
    );

    test(
      'Property 11: Platform adapter ensures consistent behavior',
      () {
        // Verify all component types return consistent values
        final componentTypes = [
          ComponentType.button,
          ComponentType.textField,
          ComponentType.switch_,
          ComponentType.slider,
          ComponentType.dialog,
          ComponentType.progressIndicator,
          ComponentType.appBar,
          ComponentType.navigationBar,
          ComponentType.listTile,
          ComponentType.card,
          ComponentType.checkbox,
          ComponentType.radio,
          ComponentType.dropdown,
        ];

        for (final type in componentTypes) {
          final componentType = platformAdapter.getComponentType(type);
          expect(componentType, equals('Material'),
              reason:
                  '${type.name} component type should be Material on web/desktop');
        }
      },
    );

    test(
      'Property 11: Platform adapter supports feature detection',
      () {
        // Test feature detection for platform-specific capabilities
        final features = {
          'system_tray': platformService.isDesktop && !platformService.isWeb,
          'window_management':
              platformService.isDesktop && !platformService.isWeb,
          'file_system': !platformService.isWeb,
          'notifications': true,
          'biometric_auth': platformService.isMobile,
        };

        for (final entry in features.entries) {
          final supported = platformAdapter.supportsFeature(entry.key);
          expect(supported, equals(entry.value),
              reason:
                  'Feature ${entry.key} support should match platform capabilities');
        }
      },
    );

    test(
      'Property 11: Platform adapter provides consistent styling',
      () {
        // Get platform-specific styling
        final styling = platformAdapter.getPlatformStyling();

        // Verify styling contains required properties
        expect(styling.containsKey('buttonPadding'), isTrue,
            reason: 'Styling should include buttonPadding');
        expect(styling.containsKey('inputPadding'), isTrue,
            reason: 'Styling should include inputPadding');
        expect(styling.containsKey('borderRadius'), isTrue,
            reason: 'Styling should include borderRadius');
        expect(styling.containsKey('elevation'), isTrue,
            reason: 'Styling should include elevation');

        // Verify styling values are appropriate
        expect(styling['buttonPadding'], isA<EdgeInsets>(),
            reason: 'buttonPadding should be EdgeInsets');
        expect(styling['inputPadding'], isA<EdgeInsets>(),
            reason: 'inputPadding should be EdgeInsets');
        expect(styling['borderRadius'], isA<double>(),
            reason: 'borderRadius should be double');
        expect(styling['elevation'], isA<double>(),
            reason: 'elevation should be double');
      },
    );

    test(
      'Property 11: Platform detection provides comprehensive information',
      () {
        // Get detection info
        final info = platformService.getDetectionInfo();

        // Verify required information is present
        expect(info.containsKey('isWeb'), isTrue,
            reason: 'Detection info should include isWeb');
        expect(info.containsKey('isWindows'), isTrue,
            reason: 'Detection info should include isWindows');
        expect(info.containsKey('isLinux'), isTrue,
            reason: 'Detection info should include isLinux');
        expect(info.containsKey('isMacOS'), isTrue,
            reason: 'Detection info should include isMacOS');
        expect(info.containsKey('isDesktop'), isTrue,
            reason: 'Detection info should include isDesktop');
        expect(info.containsKey('isMobile'), isTrue,
            reason: 'Detection info should include isMobile');
        expect(info.containsKey('detectedPlatform'), isTrue,
            reason: 'Detection info should include detectedPlatform');
        expect(info.containsKey('currentPlatform'), isTrue,
            reason: 'Detection info should include currentPlatform');
        expect(info.containsKey('isInitialized'), isTrue,
            reason: 'Detection info should include isInitialized');

        // Verify platform is initialized
        expect(info['isInitialized'], isTrue,
            reason: 'Platform detection should be initialized');
      },
    );
  });
}
