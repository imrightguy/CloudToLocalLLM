# Settings Widgets

This directory contains reusable widgets for building settings UI components.

## Base Widgets

### `settings_base.dart`

- **SettingsSectionWidget** - Base widget for a settings section with title and description
- **SettingsItemWidget** - Base widget for a single settings item with label and control
- **SettingsGroup** - Settings group container with dividers and optional title
- **SettingsForm** - Settings form container with save/cancel buttons and error handling

### `settings_category_widgets.dart`

- **SettingsCategoryContentWidget** - Base widget for settings category content
- **SettingsCategoryListItem** - Category list item with icon, title, and description
- **SettingsSearchResultItem** - Search result item showing category and setting
- **SettingsValidationError** - Validation error display with dismiss button
- **SettingsSuccessMessage** - Success message with auto-dismiss animation

### `settings_input_widgets.dart`

- **SettingsTextInput** - Text input with label, description, and error handling
- **SettingsToggle** - Toggle/switch with label and description
- **SettingsDropdown** - Dropdown with label, description, and error handling
- **SettingsButton** - Button with label, description, and loading state
- **SettingsSlider** - Slider with label, description, and value display

## Usage Examples

### Text Input

```dart
SettingsTextInput(
  label: 'API Key',
  description: 'Enter your API key',
  value: apiKey,
  onChanged: (value) => setState(() => apiKey = value),
  hintText: 'sk-...',
  errorMessage: apiKeyError,
)
```

### Toggle

```dart
SettingsToggle(
  label: 'Enable Analytics',
  description: 'Help us improve by sharing usage data',
  value: analyticsEnabled,
  onChanged: (value) => setState(() => analyticsEnabled = value),
)
```

### Dropdown

```dart
SettingsDropdown<String>(
  label: 'Theme',
  description: 'Choose your preferred theme',
  value: selectedTheme,
  items: [
    DropdownMenuItem(value: 'light', child: Text('Light')),
    DropdownMenuItem(value: 'dark', child: Text('Dark')),
    DropdownMenuItem(value: 'system', child: Text('System')),
  ],
  onChanged: (value) => setState(() => selectedTheme = value),
)
```

### Settings Group

```dart
SettingsGroup(
  title: 'General Settings',
  description: 'Configure general preferences',
  children: [
    SettingsToggle(label: 'Option 1', value: true),
    SettingsToggle(label: 'Option 2', value: false),
  ],
)
```

### Settings Form

```dart
SettingsForm(
  isDirty: hasChanges,
  isSaving: isSaving,
  errorMessage: errorMessage,
  onSave: () => saveSettings(),
  onCancel: () => discardChanges(),
  children: [
    SettingsTextInput(...),
    SettingsToggle(...),
  ],
)
```

## Accessibility

All widgets include:

- Proper semantic labels
- Keyboard navigation support
- Screen reader compatibility
- High contrast support
- Touch target sizing (minimum 44x44 pixels on mobile)

## Responsive Design

Widgets adapt to different screen sizes:

- Mobile (< 600px): Full-width inputs, stacked layout
- Tablet (600-1024px): Optimized spacing, two-column layout
- Desktop (> 1024px): Three-column layout with sidebar

## Theming

All widgets respect the current theme:

- Material Design colors
- Custom theme extensions
- Dark mode support
- High contrast mode support
