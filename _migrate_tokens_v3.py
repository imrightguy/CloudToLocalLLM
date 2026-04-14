#!/usr/bin/env python3
"""Migrate hardcoded colors, spacing, and patterns to design tokens - V3 (no AppBar)."""

import re
import glob

COLOR_MAP = {
    "0xFF0F766E": "AppColors.primary",
    "0xFF14B8A6": "AppColors.primaryLight",
    "0x1A0F766E": "AppColors.primarySurface",
    "0xFF1E293B": "AppColors.textPrimary",
    "0xFF64748B": "AppColors.textSecondary",
    "0xFF94A3B8": "AppColors.textMuted",
    "0xFFF8FAFC": "AppColors.background",
    "0xFFF1F5F9": "AppColors.surfaceVariant",
    "0xFFE2E8F0": "AppColors.border",
    "0xFF10B981": "AppColors.success",
    "0xFFF59E0B": "AppColors.warning",
    "0xFFEF4444": "AppColors.error",
    "0xFF3B82F6": "AppColors.info",
    "0xFF475569": "AppColors.label",
    "0xFFCBD5E1": "AppColors.disabled",
    "0xFF6366F1": "AppColors.indigo",
    "0xFFE0E7FF": "AppColors.indigoTint",
    "0xFF4338CA": "AppColors.indigoDark",
    "0xFF38BDF8": "AppColors.skyBlue",
    "0xFF6B7280": "AppColors.stageNouveau",
    "0xFF8B5CF6": "AppColors.stageVisitePlanifiee",
    "0xFF059669": "AppColors.funnelBailSigne",
    "0xFFB45309": "AppColors.warningDark",
    "0xFFFCA5A5": "AppColors.errorLight",
    "0xFFCD7F32": "AppColors.rankBronze",
}

FILES = sorted(glob.glob("lib/screens/*.dart")) + ["lib/main.dart"]


def replace_color_hexes(content):
    for hex_val, replacement in sorted(COLOR_MAP.items(), key=lambda x: -len(x[0])):
        if replacement is None:
            continue
        content = re.sub(r"\bconst\s+Color\(0x" + hex_val[2:] + r"\)", replacement, content)
        content = re.sub(r"\bColor\(0x" + hex_val[2:] + r"\)", replacement, content)
    return content


def replace_safe_colors_white(content):
    content = re.sub(r"backgroundColor:\s*Colors\.white\b", "backgroundColor: AppColors.surface", content)
    content = re.sub(r"fillColor:\s*Colors\.white\b", "fillColor: AppColors.surface", content)
    content = re.sub(r"surfaceTintColor:\s*Colors\.white\b", "surfaceTintColor: AppColors.surface", content)
    return content


def replace_card_decorations(content):
    pattern = re.compile(
        r"BoxDecoration\(\s*\n"
        r"(\s*)color:\s*(?:const\s+)?(?:AppColors\.surface|Colors\.white),\s*\n"
        r"\1borderRadius:\s*BorderRadius\.circular\(12\),\s*\n"
        r"\1boxShadow:\s*\[\s*\n"
        r"\1\s*BoxShadow\(\s*\n"
        r"\1\s*color:\s*Colors\.black\.withValues\(alpha:\s*0\.05\),\s*\n"
        r"\1\s*blurRadius:\s*10,\s*\n"
        r"\1\s*offset:\s*const\s+Offset\(0,\s*2\),\s*\n"
        r"\1\s*\),\s*\n"
        r"\1\],\s*\n"
        r"\1\)",
        re.MULTILINE
    )
    return pattern.sub("AppSpacing.cardDecoration()", content)


def replace_elevation_shadows(content):
    pattern = re.compile(
        r"BoxShadow\(\s*\n"
        r"(\s*)color:\s*Colors\.black\.withValues\(alpha:\s*0\.05\),\s*\n"
        r"\1blurRadius:\s*10,\s*\n"
        r"\1offset:\s*const\s+Offset\(0,\s*2\),\s*\n"
        r"\1\)",
        re.MULTILINE
    )
    return pattern.sub("AppSpacing.elevationCard", content)


def add_imports(content, filepath):
    rel = "../" if filepath.startswith("lib/screens/") else ""
    needs = []
    if "AppColors." in content and "import '" + rel + "theme/app_colors.dart'" not in content:
        needs.append("import '" + rel + "theme/app_colors.dart';")
    if "AppSpacing." in content and "import '" + rel + "theme/app_spacing.dart'" not in content:
        needs.append("import '" + rel + "theme/app_spacing.dart';")
    if not needs:
        return content
    lines = content.split("\n")
    last_import = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("import "):
            last_import = i
    if last_import < 0:
        return content
    for imp in reversed(needs):
        lines.insert(last_import + 1, imp)
    return "\n".join(lines)


def remove_duplicate_imports(content):
    lines = content.split("\n")
    seen = set()
    result = []
    for line in lines:
        s = line.strip()
        if s.startswith("import ") and s in seen:
            continue
        if s.startswith("import "):
            seen.add(s)
        result.append(line)
    return "\n".join(result)


def process_file(filepath):
    print(f"Processing {filepath}...")
    with open(filepath) as f:
        content = f.read()
    original = content
    content = replace_color_hexes(content)
    content = replace_safe_colors_white(content)
    content = replace_card_decorations(content)
    content = replace_elevation_shadows(content)
    content = add_imports(content, filepath)
    content = remove_duplicate_imports(content)
    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"  -> Modified")
    else:
        print(f"  -> No changes")


if __name__ == "__main__":
    for fp in FILES:
        process_file(fp)
    
    print("\n--- Summary ---")
    total_hex = total_white = 0
    for fp in FILES:
        with open(fp) as f:
            c = f.read()
        total_hex += len(re.findall(r"Color\(0x", c))
        total_white += len(re.findall(r"Colors\.white", c))
    print(f"Remaining Color(0x...): {total_hex}")
    print(f"Remaining Colors.white: {total_white}")
