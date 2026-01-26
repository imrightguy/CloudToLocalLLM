# Responsive Layout and Accessibility Implementation

## Overview

This document describes the implementation of responsive layout and accessibility features for the Platform Settings Screen, ensuring WCAG 2.1 AA compliance across all platforms (web, Windows, Linux, mobile).

## Responsive Breakpoints

The settings screen adapts to three main breakpoints:

### Mobile (< 600px)

- Single-column layout
- Full-width inputs and buttons
- Compact spacing (12px padding)
- Touch targets: 44x44 pixels minimum
- Vertical category navigation
- Search bar at top

### Tablet (600px - 1024px)

- Two-column layout
- Left sidebar (280px) for category navigation
- Right panel for content
- Medium spacing (16px padding)
- Touch targets: 44x44 pixels minimum
- Horizontal divider between columns

### Desktop (> 1024px)

- Three-column layout (optional)
- Left sidebar (280px) for category navigation
- Right panel for content
- Generous spacing (24px padding)
- Touch targets: 32x32 pixels minimum
- Horizontal divider between columns

## Accessibility Features

### WCAG 2.1 AA Compliance

#### 1. Semantic HTML and Structure (Web Platform)

- All interactive elements use semantic HTML
- Proper heading hierarchy (h1, h2, h3)
- Form labels associated with inputs
- List elements for category navigation
- Navigation landmarks

#### 2. ARIA Labels and Attributes

- All buttons have descriptive labels
- Form inputs have associated labels
- Icons have aria-labels
- Active states announced (e.g., "selected")
- Error messages linked to inputs

#### 3. Keyboard Navigation

- Tab order follows visual flow
- Enter key activates buttons
- Escape key closes dialogs/clears search
- Arrow keys navigate lists
- Focus indicators visible on all interactive elements
- Keyboard shortcuts documented

#### 4. Screen Reader Support

- All text content readable by screen readers
- Form labels announced
- Error messages announced
- Status updates announced
- Skip links for navigation

#### 5. Color Contrast

- Minimum 4.5:1 contrast ratio for text (WCAG AA)
- 3:1 contrast ratio for UI components
- Color not the only means of conveying information
- Tested with contrast checking tools

#### 6. Touch Targets

- Minimum 44x44 pixels on mobile
- Minimum 32x32 pixels on desktop
- Adequate spacing between targets
- Larger targets for frequently used actions

#### 7. Text and Font

- Readable font sizes (minimum 12px)
- Sufficient line height (1.5x)
- Adequate letter spacing
- Support for text scaling up to 200%
- No fixed font sizes that prevent scaling

#### 8. Motion and Animation

- Animations respect prefers-reduced-motion
- No auto-playing animations
- Animations can be paused
- Animations don't distract from content

#### 9. Focus Management

- Focus visible on all interactive elements
- Focus order logical and intuitive
- Focus trap in modals
- Focus restored after closing modals

#### 10. Error Prevention and Recovery

- Clear error messages
- Suggestions for correction
- Confirmation for destructive actions
- Ability to undo actions

## Implementation Details

### Responsive Layout Components

#### ResponsiveLayout Utility

```dart
// Get current screen size
final screenSize = ResponsiveLayout.getScreenSize(context);

// Check screen type
if (ResponsiveLayout.isMobile(context)) {
  // Mobile layout
} else if (ResponsiveLayout.isTablet(context)) {
  // Tablet layout
} else {
  // Desktop layout
}

// Get responsive values
final padding = ResponsiveLayout.getResponsivePadding(context);
final fontSize = ResponsiveLayout.getResponsiveFontSize(
  context,
  mobileSize: 14,
  tabletSize: 16,
  desktopSize: 18,
);
```

#### ResponsiveContainer Widget

```dart
ResponsiveContainer(
  maxWidth: 1200,
  padding: const EdgeInsets.all(16),
  child: YourContent(),
)
```

#### ResponsiveWidget

```dart
ResponsiveWidget(
  builder: (context, screenSize) {
    switch (screenSize) {
      case ScreenSize.mobile:
        return MobileLayout();
      case ScreenSize.tablet:
        return TabletLayout();
      case ScreenSize.desktop:
        return DesktopLayout();
    }
  },
)
```

### Accessibility Components

#### AccessibleTextInput

```dart
AccessibleTextInput(
  label: 'Email Address',
  description: 'Enter your email for account recovery',
  value: email,
  onChanged: (value) => setState(() => email = value),
  errorMessage: emailError,
  prefixIcon: Icons.email,
)
```

#### AccessibleToggle

```dart
AccessibleToggle(
  label: 'Enable Notifications',
  description: 'Receive notifications for important updates',
  value: notificationsEnabled,
  onChanged: (value) => setState(() => notificationsEnabled = value),
)
```

#### AccessibleButton

```dart
AccessibleButton(
  label: 'Save Settings',
  description: 'Save all changes to your settings',
  onPressed: _saveSettings,
  icon: Icons.save,
)
```

#### AccessibleDropdown

```dart
AccessibleDropdown<String>(
  label: 'Theme',
  description: 'Choose your preferred theme',
  items: [
    DropdownMenuItem(value: 'light', child: Text('Light')),
    DropdownMenuItem(value: 'dark', child: Text('Dark')),
  ],
  initialValue: currentTheme,
  onChanged: (value) => setState(() => currentTheme = value),
)
```

### Semantic Labels

All interactive elements include semantic labels:

```dart
Semantics(
  label: 'Settings category: General',
  button: true,
  enabled: true,
  onTap: () => selectCategory('general'),
  child: CategoryButton(),
)
```

### Keyboard Navigation

The settings screen supports full keyboard navigation:

- **Tab**: Move to next interactive element
- **Shift+Tab**: Move to previous interactive element
- **Enter**: Activate button or select item
- **Space**: Toggle checkbox or switch
- **Escape**: Close search or dialog
- **Arrow Up/Down**: Navigate lists
- **Arrow Left/Right**: Navigate tabs or radio buttons

### Focus Management

Focus is managed automatically:

```dart
FocusNode _focusNode = FocusNode();

// Request focus
_focusNode.requestFocus();

// Listen for focus changes
_focusNode.addListener(() {
  if (_focusNode.hasFocus) {
    // Handle focus gained
  }
});

// Dispose
_focusNode.dispose();
```

### Color Contrast

Contrast is verified using the AccessibilityHelpers utility:

```dart
final meetsRequirement = AccessibilityHelpers.meetsContrastRequirement(
  foregroundColor,
  backgroundColor,
);
```

## Testing Accessibility

### Manual Testing

1. Navigate using keyboard only
2. Test with screen reader (NVDA, JAWS, VoiceOver)
3. Check color contrast with tools
4. Test on multiple screen sizes
5. Test with browser zoom (up to 200%)
6. Test with high contrast mode

### Automated Testing

1. Use accessibility testing libraries
2. Run contrast checking tools
3. Validate semantic HTML
4. Check ARIA attributes
5. Verify keyboard navigation

### Browser DevTools

1. Chrome DevTools Accessibility Audit
2. Firefox Accessibility Inspector
3. Safari Accessibility Inspector
4. Edge DevTools Accessibility

## Platform-Specific Considerations

### Web Platform

- Use semantic HTML
- Implement ARIA labels
- Support keyboard navigation
- Test with screen readers
- Ensure proper heading hierarchy
- Use skip links

### Windows Desktop

- Support Narrator
- Implement keyboard shortcuts
- Use native-feeling widgets
- Support high contrast mode
- Implement window management

### Linux Desktop

- Support screen readers
- Implement keyboard shortcuts
- Use native-feeling widgets
- Support high contrast mode

### Mobile Platforms

- Support VoiceOver (iOS)
- Support TalkBack (Android)
- Ensure 44x44 touch targets
- Support dynamic type
- Implement haptic feedback

## Best Practices

1. **Test Early and Often**: Test accessibility throughout development
2. **Use Semantic Components**: Prefer semantic widgets over custom implementations
3. **Provide Alternatives**: Offer keyboard and voice alternatives to mouse actions
4. **Clear Labels**: Use clear, descriptive labels for all inputs
5. **Error Messages**: Provide clear, actionable error messages
6. **Focus Indicators**: Ensure focus is always visible
7. **Color Contrast**: Maintain sufficient contrast ratios
8. **Responsive Design**: Test on multiple screen sizes
9. **Performance**: Ensure animations don't impact performance
10. **Documentation**: Document accessibility features for users

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility](https://flutter.dev/docs/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [WebAIM](https://webaim.org/)
- [A11y Project](https://www.a11yproject.com/)

## Verification Checklist

- [ ] Responsive layout works on mobile, tablet, and desktop
- [ ] All interactive elements are keyboard accessible
- [ ] Focus indicators are visible
- [ ] Color contrast meets WCAG AA standards
- [ ] Touch targets are at least 44x44 pixels on mobile
- [ ] Screen reader support verified
- [ ] Semantic labels present on all elements
- [ ] Error messages are clear and actionable
- [ ] Animations respect prefers-reduced-motion
- [ ] Text scales properly up to 200%
- [ ] No color-only information conveyance
- [ ] Keyboard shortcuts documented
- [ ] Tested on multiple browsers
- [ ] Tested with screen readers
- [ ] Tested with keyboard only
- [ ] Tested on multiple screen sizes
