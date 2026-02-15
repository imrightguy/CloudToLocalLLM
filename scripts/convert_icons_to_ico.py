#!/usr/bin/env python3
"""
Convert PNG tray icons to ICO format for Windows system tray compatibility.

This script converts the existing Zoidbot PNG tray icons to ICO format
with multiple embedded sizes (16x16, 24x24, 32x32, 48x48) for optimal Windows
system tray display across different DPI settings and themes.
"""

import os
import sys
from PIL import Image
from pathlib import Path

def convert_png_to_ico(png_path, ico_path, sizes=[16, 24, 32, 48]):
    """
    Convert a PNG file to ICO format with multiple embedded sizes.
    
    Args:
        png_path (str): Path to the source PNG file
        ico_path (str): Path for the output ICO file
        sizes (list): List of sizes to embed in the ICO file
    """
    try:
        # Open the source PNG image
        with Image.open(png_path) as img:
            # Convert to RGBA if not already
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Create list of resized images for different sizes
            icon_images = []
            for size in sizes:
                # Resize image to target size with high-quality resampling
                resized = img.resize((size, size), Image.Resampling.LANCZOS)
                icon_images.append(resized)
            
            # Save as ICO with multiple sizes embedded
            icon_images[0].save(
                ico_path,
                format='ICO',
                sizes=[(size, size) for size in sizes],
                append_images=icon_images[1:]
            )
            
            print(f"✅ Converted {png_path} -> {ico_path} (sizes: {sizes})")
            return True
            
    except Exception as e:
        print(f"❌ Error converting {png_path}: {e}")
        return False

def main():
    """Main conversion function."""
    # Get the project root directory
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    assets_dir = project_root / "assets" / "images"
    
    print("🔄 Zoidbot Icon Converter - PNG to ICO")
    print(f"📁 Assets directory: {assets_dir}")
    
    # Define the tray icons to convert
    tray_icons = [
        "tray_icon.png",  # Generic fallback icon
        "tray_icon_connected.png",
        "tray_icon_disconnected.png",
        "tray_icon_connecting.png",
        "tray_icon_partial.png"
    ]
    
    # ICO sizes for Windows system tray (16x16, 24x24, 32x32, 48x48)
    ico_sizes = [16, 24, 32, 48]
    
    success_count = 0
    total_count = len(tray_icons)
    
    # Convert each tray icon
    for png_filename in tray_icons:
        png_path = assets_dir / png_filename
        ico_filename = png_filename.replace('.png', '.ico')
        ico_path = assets_dir / ico_filename
        
        if not png_path.exists():
            print(f"⚠️  Source file not found: {png_path}")
            continue
            
        print(f"🔄 Converting {png_filename}...")
        if convert_png_to_ico(str(png_path), str(ico_path), ico_sizes):
            success_count += 1
    
    # Summary
    print(f"\n📊 Conversion Summary:")
    print(f"✅ Successfully converted: {success_count}/{total_count} icons")
    
    if success_count == total_count:
        print("🎉 All tray icons converted successfully!")
        print("📝 Next steps:")
        print("   1. Update native_tray_service.dart to use .ico files on Windows")
        print("   2. Add .ico files to pubspec.yaml assets")
        print("   3. Test system tray display on Windows")
        return 0
    else:
        print("⚠️  Some conversions failed. Please check the errors above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
