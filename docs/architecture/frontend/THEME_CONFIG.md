# Unified Theme Configuration

## Overview

The `ThemeConfig` class provides a centralized, unified theme configuration system for the CloudToLocalLLM application. It supports Light, Dark, and System themes with platform-specific variations and comprehensive validation.

## Features

### 1. Theme Modes

- **Light Mode**: Bright colors optimized for daylight viewing
- **Dark Mode**: Dark colors optimized for low-light environments
- **System Mode**: Automatically follows device theme settings

### 2. Color Definitions

#### Brand Colors

- Primary: `#a777e3` (Purple)
- Secondary: `#6e8efb` (Blue)
- Accent: `#00c58e` (Green)

#### Dark Mode Colors

- Background Main: `#181a20`
- Background Card: `#23243a`
- Text Color: `#f1f1f1`
- Text Color Light: `#b0b0b0`

#### Light Mode Colors

- Background Main: White
- Background Card: `#F1F2F4`
- Text Color: `#2c3e50`
- Text Color Light: `#6F7B8A`

#### Status Colors

- Success: `#4caf50` (Dark) / `#2E7D32` (Light)
- Warning: `#ffa726` (Dark) / `#F57C00` (Light)
- Danger: `#ff5252` (Dark) / `#D32F2F` (Light)
- Info: `#2196f3` (Dark) / `#1976D2` (Light)

### 3. Typography

All text styles follow a consistent hierarchy:

- Display Large: 32px, Bold
- Display Medium: 28px, Bold
- Headline Large: 24px, Semi-bold
- Headline Medium: 20px, Semi-bold
- Headline Small: 18px, Semi-bold
- Body Large: 16px, Normal
- Body Medium: 14px, Normal
- Body Small: 12px, Normal

Font fallback chain: Segoe UI → Roboto → Helvetica Neue → Arial → sans-serif

### 4. Spacing System

Consistent spacing values:

- XS: 4px
- S: 8px
- M: 16px
- L: 24px
- XL: 32px
- XXL: 48px

### 5. Border Radius

- Small: 8px
- Medium: 16px
- Large: 24px

### 6. Elevation

- Low: 2.0
- Medium: 4.0
- High: 8.0
- Very High: 16.0

## Platform-Specific Variations

### Spacing Adjustments

- **Desktop (Windows/Linux)**: 1.1x base spacing
- **Mobile (iOS/Android)**: 1.0x base spacing
- **Web**: 1.0x base spacing

### Font Size Adjustments

- **Desktop (Windows/Linux)**: 1.05x base font size
- **Mobile (iOS/Android)**: 1.0x base font size
- **Web**: 1.0x base font size

### Elevation Adjustments

- **Desktop (Windows/Linux)**: 0.8x base elevation
- **iOS**: 0.5x base elevation (minimal)
- **Android**: 1.0x base elevation
- **Web**: 1.0x base elevation

## Theme Validation

The `ThemeConfig` class includes comprehensive validation:

### Contrast Ratio Validation

- Validates WCAG AA compliance (4.5:1 for normal text, 3:1 for large text)
- Checks primary, secondary, and surface color contrasts
- Returns validation results with errors and warnings

### Theme Validation

- Validates color scheme brightness matches expected mode
- Checks for proper theme structure
- Returns detailed validation results

## Usage

### Loading a Theme

```dart
// Load dark theme
final darkTheme = ThemeConfig.loadThemeConfiguration(
  ThemeMode.dark,
  null,
);

// Load light theme
final lightTheme = ThemeConfig.loadThemeConfiguration(
  ThemeMode.light,
  null,
);

// Load system theme (respects device brightness)
final systemTheme = ThemeConfig.loadThemeConfiguration(
  ThemeMode.system,
  MediaQuery.of(context).platformBrightness,
);
```

### Validating a Theme

```dart
final theme = ThemeConfig.loadThemeConfiguration(ThemeMode.dark, null);
final result = ThemeConfig.validateTheme(theme, isDark: true);

if (result.isValid) {
  print('Theme is valid!');
} else {
  print('Errors: ${result.errors}');
  print('Warnings: ${result.warnings}');
}
```

### Platform-Specific Adjustments

```dart
// Get platform-specific spacing
final spacing = ThemeConfig.getPlatformSpacing(
  Theme.of(context).platform,
  16.0, // base spacing
);

// Get platform-specific font size
final fontSize = ThemeConfig.getPlatformFontSize(
  Theme.of(context).platform,
  16.0, // base font size
);

// Get platform-specific elevation
final elevation = ThemeConfig.getPlatformElevation(
  Theme.of(context).platform,
  8.0, // base elevation
);
```

### Validating Contrast Ratios

```dart
// Check if colors have sufficient contrast
final hasGoodContrast = ThemeConfig.validateContrastRatio(
  Colors.white,
  Colors.black,
  isLargeText: false, // requires 4.5:1 ratio
);
```

## Integration with Existing Code

The `AppTheme` class in `lib/config/theme.dart` now delegates to `ThemeConfig`:

```dart
class AppTheme {
  static ThemeData get darkTheme => ThemeConfig.loadThemeConfiguration(
        ThemeMode.dark,
        null,
      );

  static ThemeData get lightTheme => ThemeConfig.loadThemeConfiguration(
        ThemeMode.light,
        null,
      );
}
```

This ensures backward compatibility while providing the new unified theme system.

## Testing

Comprehensive tests are available in `test/config/theme_config_test.dart`:

- Theme loading for all modes
- System theme mode handling
- Contrast ratio validation
- Theme validation
- Platform-specific adjustments

Run tests with:

```bash
flutter test test/config/theme_config_test.dart
```

## Requirements Satisfied

This implementation satisfies the following requirements from the unified app theming spec:

- **Requirement 1.1**: Centralized theme configuration for all screens
- **Requirement 1.5**: Support for Light, Dark, and System theme modes

## Next Steps

1. Update `ThemeProvider` to use `ThemeConfig` for theme loading
2. Apply unified theme configuration across all screens
3. Implement platform-specific component selection
4. Add theme persistence and caching
5. Implement real-time theme updates

## Notes

- All themes use Material Design 3 (`useMaterial3: true`)
- Theme extensions (`AppSpacingTheme`, `AppColorsTheme`) are preserved for backward compatibility
- Platform-specific adjustments are optional and can be applied as needed
- Validation is performed automatically but can be disabled if needed
