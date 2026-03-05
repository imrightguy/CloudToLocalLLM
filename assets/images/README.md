# OpenClaw Logo Asset

## Status

The OpenClaw logo (`openclaw_logo.png`) is not currently included in this repository.

## Fallback Behavior

The `OpenClawNavigationShell` widget has been implemented with a graceful fallback mechanism. When the logo file is missing, it automatically displays `Icons.smart_toy` instead.

See: `/run/media/rightguy/data_storage/dev/CloudToLocalLLM/lib/widgets/navigation/openclaw_navigation_shell.dart` line 94

```dart
Image.asset(
  'assets/images/openclaw_logo.png',
  width: 32,
  height: 32,
  errorBuilder: (ctx, _, __) => const Icon(Icons.smart_toy, size: 32)
)
```

## Adding the Actual Logo

To add the official OpenClaw logo:

1. **File**: Place `openclaw_logo.png` in this directory
2. **Recommended size**: 32x32 pixels for the sidebar display
3. **Format**: PNG with transparency support
4. **Theme consideration**: The logo should work well in both light and dark themes, or provide two versions (e.g., `openclaw_logo_dark.png` and `openclaw_logo_light.png`)

## Existing Assets

This directory contains various application assets:
- `app_icon.png` - Main application icon
- `lobster_avatar.png` - Avatar images for CloudToLocalLLM character
- `tray_icon_*.png` - System tray icons (connected, disconnected, connecting, etc.)
- Various themed tray icons (dark, contrast, mono)

## Notes

- The `assets/images/` directory is already configured in `pubspec.yaml`
- No code changes are needed when adding the actual logo - the widget will automatically load it
- The current fallback provides a functional substitute until the official logo is available
