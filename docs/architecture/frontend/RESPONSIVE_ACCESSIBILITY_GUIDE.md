# Responsive Layout and Accessibility Guide

This guide documents the responsive layout and accessibility features implemented for the Platform Settings Screen.

## Overview

The settings screen implements comprehensive responsive design and accessibility features to ensure usability across all platforms and devices, with support for screen readers, keyboard navigation, and proper contrast ratios.

## Responsive Design

### Screen Size Breakpoints

The application uses three main breakpoints for responsive design:

- **Mobile**: < 600px (phones)
- **Tablet**: 600px - 1024px (tablets)
- **Desktop**: > 1024px (desktop computers)

### Using ResponsiveLayout

The `ResponsiveLayout` utility class provides helpers for building responsive UIs:

```dart
import 'package:cloud_to_local_llm/utils/responsive_layout.dart';

// Get current screen size classification
final screenSize = ResponsiveLayout.getScreenSize(context);

// Check specific screen sizes
if (ResponsiveLayout.isMobile(context)) {
  // Mobile-specific layout
}

// Get responsive padding
final padding = ResponsiveLayout.getResponsivePadding(context);

// Get responsive column count for grids
final columns = ResponsiveLayout.getResponsiveColumnCount(context);
```

### Layout Adaptations

#### Mobile Layout (< 600px)

- Single column layout
- Full-width inputs
- Stacked navigation
- Minimum 12px padding
- 1 column grid

#### Tablet Layout (600px - 1024px)

- Two column layout (sidebar + content)
- Optimized spacing
- 16px padding
- 2 column grid

#### Desktop Layout (> 1024px)

- Three column layout (sidebar + content + optional panel)
- Generous spacing
- 24px padding
- 3 column grid

### Responsive Container

Use `ResponsiveContainer` for automatic responsive padding:

```dart
ResponsiveContainer(
  maxWidth: 1200,
  child: YourContent(),
)
```

## Accessibility Features

### WCAG 2.1 AA Compliance

All components meet WCAG 2.1 AA standards:

- **Contrast Ratio**: Minimum 4.5:1 for normal text
- **Touch Targets**: Minimum 44x44 pixels on mobile, 32x32 on desktop
- **Keyboard Navigation**: Full support for Tab, Enter, Escape
- **Screen Reader Support**: Proper semantic labels and descriptions

### Semantic Labels

All interactive elements include semantic labels for screen readers:

```dart
Semantics(
  label: 'Save settings',
  button: true,
  onTap: () => saveSettings(),
  child: FilledButton(
    onPressed: () => saveSettings(),
    child: const Text('Save'),
  ),
)
```

### Accessible Input Widgets

Use accessible input widgets for better screen reader support:

```dart
// Accessible text input
AccessibleTextInput(
  label: 'Email',
  description: 'Enter your email address',
  value: email,
  onChanged: (value) => setState(() => email = value),
  errorMessage: emailError,
)

// Accessible toggle
AccessibleToggle(
  label: 'Enable notifications',
  description: 'Receive push notifications',
  value: notificationsEnabled,
  onChanged: (value) => setState(() => notificationsEnabled = value),
)

// Accessible button
AccessibleButton(
  label: 'Save',
  description: 'Save your changes',
  onPressed: () => saveSettings(),
)

// Accessible dropdown
AccessibleDropdown<String>(
  label: 'Theme',
  description: 'Choose your preferred theme',
  items: themeOptions,
  value: selectedTheme,
  onChanged: (value) => setState(() => selectedTheme = value),
)
```

### Keyboard Navigation

All settings components support keyboard navigation:

- **Tab**: Move to next element
- **Shift+Tab**: Move to previous element
- **Enter**: Activate button or submit form
- **Space**: Toggle switch or checkbox
- **Escape**: Close dropdown or clear search
- **Arrow Keys**: Navigate dropdown options or adjust slider

### Screen Reader Support

Screen readers (VoiceOver on iOS, TalkBack on Android, Narrator on Windows) receive:

- Semantic labels for all interactive elements
- Error messages and validation feedback
- Current state information (toggled, selected, etc.)
- Descriptions for complex controls

### Contrast Ratio Validation

Use `AccessibilityHelpers` to validate color contrast:

```dart
import 'package:cloud_to_local_llm/utils/accessibility_helpers.dart';

final meetsRequirement = AccessibilityHelpers.meetsContrastRequirement(
  foregroundColor,
  backgroundColor,
);
```

## Implementation Examples

### Responsive Settings Screen

```dart
class MySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenSize = ResponsiveLayout.getScreenSize(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Settings screen',
          child: const Text('Settings'),
        ),
      ),
      body: switch (screenSize) {
        ScreenSize.mobile => _buildMobileLayout(),
        ScreenSize.tablet => _buildTabletLayout(),
        ScreenSize.desktop => _buildDesktopLayout(),
      },
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildCategoryList()),
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(width: 280, child: _buildCategoryList()),
        const VerticalDivider(),
        Expanded(child: _buildContent()),
      ],
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 280, child: _buildCategoryList()),
        const VerticalDivider(),
        Expanded(child: _buildContent()),
      ],
    );
  }
}
```

### Accessible Form

```dart
class SettingsForm extends StatefulWidget {
  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  String email = '';
  bool notificationsEnabled = false;
  String? emailError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AccessibleTextInput(
          label: 'Email',
          description: 'Your account email address',
          value: email,
          onChanged: (value) => setState(() {
            email = value;
            emailError = null;
          }),
          errorMessage: emailError,
        ),
        AccessibleToggle(
          label: 'Enable notifications',
          description: 'Receive email notifications',
          value: notificationsEnabled,
          onChanged: (value) => setState(() => notificationsEnabled = value),
        ),
        AccessibleButton(
          label: 'Save',
          description: 'Save your settings',
          onPressed: _saveSettings,
        ),
      ],
    );
  }

  void _saveSettings() {
    if (email.isEmpty) {
      setState(() => emailError = 'Email is required');
      return;
    }
    // Save settings
  }
}
```

## Testing Responsive and Accessibility Features

### Responsive Testing

```dart
testWidgets('Settings screen adapts to mobile layout', (WidgetTester tester) async {
  await tester.binding.window.physicalSizeTestValue = const Size(400, 800);
  addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

  await tester.pumpWidget(const MyApp());

  expect(find.byType(Column), findsWidgets); // Mobile layout uses Column
});
```

### Accessibility Testing

```dart
testWidgets('Settings screen has proper semantic labels', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());

  expect(
    find.bySemanticsLabel('Save settings'),
    findsOneWidget,
  );
});
```

## Best Practices

### 1. Always Use Semantic Labels

```dart
// Good
Semantics(
  label: 'Save settings',
  button: true,
  child: FilledButton(...),
)

// Avoid
FilledButton(child: const Text('Save'))
```

### 2. Provide Descriptions

```dart
// Good
AccessibleTextInput(
  label: 'Email',
  description: 'Enter your email address',
  ...
)

// Avoid
AccessibleTextInput(
  label: 'Email',
  ...
)
```

### 3. Use Responsive Utilities

```dart
// Good
final padding = ResponsiveLayout.getResponsivePadding(context);

// Avoid
const padding = EdgeInsets.all(16);
```

### 4. Test on Multiple Screen Sizes

- Test on actual devices or emulators
- Use device preview tools
- Test with screen readers enabled

### 5. Ensure Sufficient Contrast

```dart
// Validate contrast ratios
final isAccessible = AccessibilityHelpers.meetsContrastRequirement(
  textColor,
  backgroundColor,
);
```

## Platform-Specific Considerations

### Web

- Use semantic HTML structure
- Provide ARIA labels
- Support keyboard navigation
- Test with browser accessibility tools

### Windows Desktop

- Support Narrator screen reader
- Provide keyboard shortcuts
- Ensure proper focus indicators
- Test with Windows accessibility settings

### Linux Desktop

- Support screen readers (Orca)
- Provide keyboard navigation
- Ensure proper focus indicators

### iOS

- Support VoiceOver
- Provide proper touch targets (44x44 minimum)
- Use dynamic type for text sizing
- Test with VoiceOver enabled

### Android

- Support TalkBack
- Provide proper touch targets (44x44 minimum)
- Use dynamic type for text sizing
- Test with TalkBack enabled

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility](https://flutter.dev/docs/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [Web Content Accessibility Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

## Troubleshooting

### Screen Reader Not Reading Labels

Ensure all interactive elements have semantic labels:

```dart
Semantics(
  label: 'Descriptive label',
  child: YourWidget(),
)
```

### Touch Targets Too Small

Use `ResponsiveLayout.getMinTouchTargetSize()` to ensure proper sizing:

```dart
final minSize = ResponsiveLayout.getMinTouchTargetSize(context);
SizedBox(
  width: minSize,
  height: minSize,
  child: YourButton(),
)
```

### Contrast Ratio Issues

Validate colors using `AccessibilityHelpers`:

```dart
if (!AccessibilityHelpers.meetsContrastRequirement(fg, bg)) {
  // Adjust colors
}
```

### Keyboard Navigation Not Working

Ensure all interactive elements are wrapped in `Semantics` with proper callbacks:

```dart
Semantics(
  button: true,
  onTap: () => handleTap(),
  child: GestureDetector(
    onTap: () => handleTap(),
    child: YourWidget(),
  ),
)
```
