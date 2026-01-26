# App Icon Generation

This directory contains scripts for generating app icons for CloudToLocalLLM across different platforms.

## Prerequisites

1. Install ImageMagick from https://imagemagick.org/script/download.php
2. Make sure the logo file is in `assets/images/CloudToLocalLLM_logo.jpg`

## Generating Icons

To generate all app icons, run the following command from the project root:

```powershell
.\scripts\generate_icons.ps1
```

This will create icons for:

- Windows (16x16, 32x32, 64x64, 256x256)
- Android (48x48, 72x72, 96x96, 144x144, 192x192)
- iOS (29x29, 40x40, 58x58, 60x60, 80x80, 87x87, 120x120, 180x180, 1024x1024)

## Icon Locations

- Windows icons: `windows/runner/Resources/`
- Android icons: `android/app/src/main/res/mipmap-*/`
- iOS icons: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Troubleshooting

If you encounter any issues:

1. Make sure ImageMagick is installed and accessible from the command line
2. Verify the logo file exists in the correct location
3. Check that you have write permissions in the target directories
