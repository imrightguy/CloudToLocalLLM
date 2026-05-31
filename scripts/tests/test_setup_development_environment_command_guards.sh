#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/setup-development-environment.sh"

python3 - <<'PY' "$TARGET_SCRIPT"
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text()
checks = [
    "require_command sudo",
    "require_command pacman",
    "require_command git",
    "require_command npm",
    "require_command systemctl",
    "trap cleanup_yay_build_dir EXIT",
    "append_line_once()",
    'ensure_shell_config_file',
    'touch "$BASHRC_FILE"',
    "append_line_once \"$BASHRC_FILE\" \"export PATH=\\\"\\$PATH:$FLUTTER_INSTALL_DIR/bin\\\"\"",
    "append_line_once \"$BASHRC_FILE\" 'export CHROME_EXECUTABLE=/usr/bin/chromium'",
    'normalize_tmpdir_root() {',
    'TMPDIR_ROOT="$(normalize_tmpdir_root "$TMPDIR")"',
    'YAY_BUILD_DIR="$(mktemp -d "$TMPDIR_ROOT/yay-install.XXXXXX")"',
    'git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR"',
    '(',
    'cd "$YAY_BUILD_DIR"',
    'makepkg -si --noconfirm',
    'require_command "$OLLAMA_CMD"',
    '"$OLLAMA_CMD" pull gemma3',
    'require_command "$KUBECTL_CMD"',
    '"$KUBECTL_CMD" version --client',
]
for needle in checks:
    if needle not in script:
        raise SystemExit(f'missing bootstrap preflight string: {needle}')

lines = script.splitlines()
helper_line = next((idx for idx, line in enumerate(lines, 1) if line.strip() == 'append_line_once() {'), None)
touch_line = next((idx for idx, line in enumerate(lines, 1) if line.strip() == 'touch "$BASHRC_FILE"'), None)
path_append_line = next((idx for idx, line in enumerate(lines, 1) if "append_line_once \"$BASHRC_FILE\" \"export PATH=\\\"\\$PATH:$FLUTTER_INSTALL_DIR/bin\\\"\"" in line), None)
chrome_append_line = next((idx for idx, line in enumerate(lines, 1) if "append_line_once \"$BASHRC_FILE\" 'export CHROME_EXECUTABLE=/usr/bin/chromium'" in line), None)

if helper_line is None or touch_line is None or path_append_line is None or chrome_append_line is None:
    raise SystemExit('missing line-order anchor while validating setup bootstrap ordering')

if not (helper_line < touch_line < path_append_line < chrome_append_line):
    raise SystemExit(
        'unexpected ordering for setup bootstrap persistence lines: '
        f'helper={helper_line}, touch={touch_line}, path={path_append_line}, chrome={chrome_append_line}'
    )

print('[test_setup_development_environment_command_guards] Passed')
PY
