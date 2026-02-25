# Accessibility Implementation Guide

## Overview

This guide explains how to implement accessibility features in CloudToLocalLLM screens using the provided accessibility components and services.

## Quick Start

### 1. Wrap Your Screen with AccessibleScreenWrapper

```dart
import 'package:CloudToLocalLLM/widgets/accessible_screen_wrapper.dart';
import 'package:CloudToLocalLLM/services/accessibility_service.dart';

class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AccessibleScreenWrapper(
      screenTitle: 'My Screen',
      screenDescription: 'Description for screen readers',
      enableKeyboardShortcuts: true,
      child: Scaffold(
        appBar: AppBar(title: Text('My Screen')),
        body: _buildBody(),
      ),
    );
  }
}
```

### 2. Use Accessible Components

Replace standard Flutter widgets with accessible versions:

```dart
// Instead of ElevatedButton
AccessibleButton(
  label: 'Save Changes',
  description: 'Save all your changes',
  icon: Icons.save,
  onPressed: () => _saveChanges(),
)

// Instead of ListTile
AccessibleListItem(
  title: 'Setting Name',
  subtitle: 'Setting description',
  leading: Icon(Icons.settings),
  onTap: () => _openSetting(),
)

// Instead of IconButton
AccessibleIconButton(
  icon: Icons.delete,
  label: 'Delete Item',
  tooltip: 'Delete this item permanently',
  onPressed: () => _deleteItem(),
)

// Instead of TextField
AccessibleTextInput(
  label: 'Username',
  description: 'Enter your username',
  value: _username,
  onChanged: (value) => setState(() => _username = value),
  hintText: 'john.doe',
)

// Instead of Switch
AccessibleToggle(
  label: 'Enable Notifications',
  description: 'Receive push notifications',
  value: _notificationsEnabled,
  onChanged: (value) => setState(() => _notificationsEnabled = value),
)
```

### 3. Organize Content with Semantic Structure

```dart
AccessibleSection(
  title: 'Account Settings',
  description: 'Manage your account preferences',
  isLandmark: true,
  child: Column(
    children: [
      AccessibleListItem(
        title: 'Email',
        subtitle: 'user@example.com',
        onTap: () => _editEmail(),
      ),
      AccessibleListItem(
        title: 'Password',
        subtitle: 'Change your password',
        onTap: () => _changePassword(),
      ),
    ],
  ),
)
```

### 4. Add Custom Keyboard Shortcuts

```dart
AccessibleScreenWrapper(
  screenTitle: 'Editor',
  keyboardShortcuts: {
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): () {
      _saveDocument();
    },
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): () {
      _createNewDocument();
    },
  },
  child: EditorContent(),
)
```

## Accessibility Service

### Setup

Add AccessibilityService to your provider tree:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AccessibilityService()),
    // Other providers
  ],
  child: MaterialApp(
    // App content
  ),
)
```

### Usage

```dart
// Access the service
final accessibilityService = context.read<AccessibilityService>();

// Enable high contrast mode
accessibilityService.enableHighContrastMode();

// Enable screen reader
accessibilityService.enableScreenReader();

// Announce to screen reader
accessibilityService.announceToScreenReader(
  context,
  'Changes saved successfully',
);

// Validate contrast ratio
final hasGoodContrast = accessibilityService.validateContrastRatio(
  Colors.black,
  Colors.white,
);

// Validate touch target size
final size = Size(48, 48);
final isValidSize = accessibilityService.validateTouchTargetSize(
  size,
  isMobile: true,
);
```

## Best Practices

### 1. Contrast Ratios

Ensure all text meets WCAG AA standards (4.5:1 minimum):

```dart
// Good contrast
Text(
  'Important Text',
  style: TextStyle(
    color: Colors.black,
    backgroundColor: Colors.white,
  ),
)

// Check contrast programmatically
if (!accessibilityService.validateContrastRatio(textColor, backgroundColor)) {
  // Use alternative colors
}
```

### 2. Touch Target Sizes

Ensure interactive elements meet minimum size requirements:

- Mobile: 44x44 pixels minimum
- Desktop: 32x32 pixels minimum

```dart
// Accessible button with proper size
AccessibleIconButton(
  icon: Icons.settings,
  label: 'Settings',
  onPressed: () {},
  // Automatically enforces minimum size
)

// Manual sizing
Container(
  constraints: BoxConstraints(
    minWidth: 44,
    minHeight: 44,
  ),
  child: InkWell(
    onTap: () {},
    child: Icon(Icons.add),
  ),
)
```

### 3. Semantic Labels

Provide clear, descriptive labels for screen readers:

```dart
// Good: Descriptive label
Semantics(
  label: 'Delete item. This action cannot be undone.',
  button: true,
  child: IconButton(
    icon: Icon(Icons.delete),
    onPressed: () => _deleteItem(),
  ),
)

// Bad: No label
IconButton(
  icon: Icon(Icons.delete),
  onPressed: () => _deleteItem(),
)
```

### 4. Keyboard Navigation

Support keyboard-only navigation:

```dart
// Focusable elements
Focus(
  onKey: (node, event) {
    if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
      _handleAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: Container(
    // Content
  ),
)

// Tab order
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(
    children: [
      FocusTraversalOrder(
        order: NumericFocusOrder(1.0),
        child: TextField(),
      ),
      FocusTraversalOrder(
        order: NumericFocusOrder(2.0),
        child: ElevatedButton(
          onPressed: () {},
          child: Text('Submit'),
        ),
      ),
    ],
  ),
)
```

### 5. Screen Reader Announcements

Announce important changes to screen reader users:

```dart
// After saving
accessibilityService.announceToScreenReader(
  context,
  'Settings saved successfully',
);

// After error
accessibilityService.announceToScreenReader(
  context,
  'Error: Unable to save settings. Please try again.',
);

// During loading
accessibilityService.announceToScreenReader(
  context,
  'Loading data. Please wait.',
);
```

## Platform-Specific Considerations

### Web

- Use semantic HTML elements
- Provide ARIA labels
- Support keyboard navigation
- Test with NVDA, JAWS, or VoiceOver

### Windows

- Test with Narrator
- Ensure keyboard shortcuts don't conflict with system shortcuts
- Provide visible focus indicators

### Linux

- Test with Orca screen reader
- Ensure GTK accessibility is enabled
- Support standard keyboard shortcuts

### iOS (Future)

- Test with VoiceOver
- Use proper accessibility traits
- Support dynamic type
- Ensure 44x44 minimum touch targets

### Android (Future)

- Test with TalkBack
- Use proper content descriptions
- Support high contrast mode
- Ensure 48x48 minimum touch targets

## Testing Accessibility

### Manual Testing

1. **Keyboard Navigation:**
   - Tab through all interactive elements
   - Verify focus indicators are visible
   - Test keyboard shortcuts

2. **Screen Reader:**
   - Enable screen reader (Narrator, VoiceOver, TalkBack)
   - Navigate through the screen
   - Verify all elements are announced correctly

3. **Contrast:**
   - Use browser DevTools or contrast checker
   - Verify all text meets 4.5:1 minimum

4. **Touch Targets:**
   - Verify all buttons are easy to tap
   - Check spacing between elements

### Automated Testing

Run the property-based tests:

```bash
# Test contrast ratios
flutter test test/integration/accessibility_contrast_ratio_property_test.dart

# Test keyboard navigation
flutter test test/integration/keyboard_navigation_property_test.dart

# Test screen reader support
flutter test test/integration/screen_reader_support_property_test.dart

# Run all accessibility tests
flutter test test/integration/accessibility_*.dart
```

## Common Issues and Solutions

### Issue: Focus not visible

**Solution:** Add focus indicator to custom widgets:

```dart
Focus(
  child: Builder(
    builder: (context) {
      final hasFocus = Focus.of(context).hasFocus;
      return Container(
        decoration: BoxDecoration(
          border: hasFocus
            ? Border.all(color: Colors.blue, width: 2)
            : null,
        ),
        child: // Content
      );
    },
  ),
)
```

### Issue: Screen reader not announcing

**Solution:** Add Semantics widget:

```dart
Semantics(
  label: 'Descriptive label',
  button: true,
  enabled: true,
  child: // Widget
)
```

### Issue: Poor contrast

**Solution:** Use theme colors or validate:

```dart
final textColor = Theme.of(context).textTheme.bodyLarge?.color;
final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

if (!accessibilityService.validateContrastRatio(textColor!, backgroundColor)) {
  // Use alternative colors
  textColor = Colors.black;
  backgroundColor = Colors.white;
}
```

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

## Support

For questions or issues with accessibility implementation, please refer to:

- `lib/services/accessibility_service.dart` - Accessibility service implementation
- `lib/widgets/accessible_screen_wrapper.dart` - Screen wrapper implementation
- `lib/utils/accessibility_helpers.dart` - Helper utilities
- `test/integration/TASK_19_ACCESSIBILITY_IMPLEMENTATION_SUMMARY.md` - Implementation summary
