#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PROJECT_ROOT="${PROJECT_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_ROOT="$SOURCE_PROJECT_ROOT"
DEFAULT_PUB_CACHE="$SOURCE_PROJECT_ROOT/.pub-cache"
MIRROR_PROJECT_ROOT=""

resolve_pub_cache() {
  local configured_pub_cache="${PUB_CACHE:-}"

  if [[ -z "$configured_pub_cache" ]]; then
    printf '%s' "$DEFAULT_PUB_CACHE"
    return 0
  fi

  case "$configured_pub_cache" in
    "$PROJECT_ROOT"/*)
      printf '%s' "$configured_pub_cache"
      return 0
      ;;
  esac

  echo "[flutter_with_cleanup] Rebinding stale PUB_CACHE=$configured_pub_cache to $DEFAULT_PUB_CACHE" >&2
  printf '%s' "$DEFAULT_PUB_CACHE"
}

export PUB_CACHE="$(resolve_pub_cache)"

cleanup_mirror_workspace() {
  if [[ -n "$MIRROR_PROJECT_ROOT" && -d "$MIRROR_PROJECT_ROOT" ]]; then
    rm -rf "$MIRROR_PROJECT_ROOT"
  fi
}

trap cleanup_mirror_workspace EXIT

prepend_tool_paths() {
  local candidate_dir
  local canonical_dir
  local path_entries=()

  for candidate_dir in "$PROJECT_ROOT/.local/bin" "$PROJECT_ROOT/../.local/bin" "$PROJECT_ROOT/.local-toolchain/wrappers" "$PROJECT_ROOT/../.local-toolchain/wrappers" "$PROJECT_ROOT/.local-toolchain/root/usr/bin" "$PROJECT_ROOT/../.local-toolchain/root/usr/bin" "$HOME/.local/bin"; do
    if [[ -d "$candidate_dir" ]]; then
      canonical_dir="$(cd "$candidate_dir" && pwd -P)"
      path_entries+=("$canonical_dir")
    fi
  done

  if [[ "${#path_entries[@]}" -eq 0 ]]; then
    return 0
  fi

  local joined_path="$(IFS=:; printf '%s' "${path_entries[*]}")"
  if [[ ":$PATH:" != *":$joined_path:"* ]]; then
    export PATH="$joined_path:$PATH"
    echo "[flutter_with_cleanup] Prepending local tool paths: $joined_path" >&2
  fi
}

prepend_tool_paths

prepend_library_paths() {
  local candidate_dir
  local canonical_dir
  local library_entries=()

  for candidate_dir in "$PROJECT_ROOT/.local-toolchain/root/usr/lib" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib" "$PROJECT_ROOT/.local-toolchain/root/usr/lib/x86_64-linux-gnu" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib/x86_64-linux-gnu" "$PROJECT_ROOT/.local-toolchain/root/usr/lib64" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib64"; do
    if [[ -d "$candidate_dir" ]]; then
      canonical_dir="$(cd "$candidate_dir" && pwd -P)"
      library_entries+=("$canonical_dir")
    fi
  done

  if [[ "${#library_entries[@]}" -eq 0 ]]; then
    return 0
  fi

  local joined_paths="$(IFS=:; printf '%s' "${library_entries[*]}")"
  if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    case ":$LD_LIBRARY_PATH:" in
      *":$joined_paths:"*) ;;
      *) export LD_LIBRARY_PATH="$joined_paths:$LD_LIBRARY_PATH" ;;
    esac
  else
    export LD_LIBRARY_PATH="$joined_paths"
  fi

  echo "[flutter_with_cleanup] Prepending local library paths: $joined_paths" >&2
}

prepend_library_paths

prepend_pkg_config_paths() {
  local candidate_dir
  local canonical_dir
  local pkgconfig_entries=()

  for candidate_dir in "$PROJECT_ROOT/.local-toolchain/root/usr/lib/pkgconfig" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib/pkgconfig" "$PROJECT_ROOT/.local-toolchain/root/usr/lib/x86_64-linux-gnu/pkgconfig" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib/x86_64-linux-gnu/pkgconfig" "$PROJECT_ROOT/.local-toolchain/root/usr/share/pkgconfig" "$PROJECT_ROOT/../.local-toolchain/root/usr/share/pkgconfig"; do
    if [[ -d "$candidate_dir" ]]; then
      canonical_dir="$(cd "$candidate_dir" && pwd -P)"
      pkgconfig_entries+=("$canonical_dir")
    fi
  done

  if [[ "${#pkgconfig_entries[@]}" -eq 0 ]]; then
    return 0
  fi

  local joined_paths="$(IFS=:; printf '%s' "${pkgconfig_entries[*]}")"
  if [[ -n "${PKG_CONFIG_PATH:-}" ]]; then
    case ":$PKG_CONFIG_PATH:" in
      *":$joined_paths:"*) ;;
      *) export PKG_CONFIG_PATH="$joined_paths:$PKG_CONFIG_PATH" ;;
    esac
  else
    export PKG_CONFIG_PATH="$joined_paths"
  fi

  echo "[flutter_with_cleanup] Prepending pkg-config paths: $joined_paths" >&2
}

prepend_pkg_config_paths

configure_pkg_config_sysroot() {
  local candidate_dir

  for candidate_dir in "$PROJECT_ROOT/.local-toolchain/root" "$PROJECT_ROOT/../.local-toolchain/root"; do
    if [[ -d "$candidate_dir" ]]; then
      export PKG_CONFIG_SYSROOT_DIR="$(cd "$candidate_dir" && pwd -P)"
      echo "[flutter_with_cleanup] Configuring PKG_CONFIG_SYSROOT_DIR: $PKG_CONFIG_SYSROOT_DIR" >&2
      return 0
    fi
  done
}

configure_pkg_config_sysroot

prepend_cmake_paths() {
  local candidate_dir
  local canonical_dir
  local cmake_entries=()

  for candidate_dir in "$PROJECT_ROOT/.local-toolchain/root/usr" "$PROJECT_ROOT/../.local-toolchain/root/usr"; do
    if [[ -d "$candidate_dir" ]]; then
      canonical_dir="$(cd "$candidate_dir" && pwd -P)"
      cmake_entries+=("$canonical_dir")
    fi
  done

  if [[ "${#cmake_entries[@]}" -eq 0 ]]; then
    return 0
  fi

  local joined_paths="$(IFS=:; printf '%s' "${cmake_entries[*]}")"
  if [[ -n "${CMAKE_PREFIX_PATH:-}" ]]; then
    case ":$CMAKE_PREFIX_PATH:" in
      *":$joined_paths:"*) ;;
      *) export CMAKE_PREFIX_PATH="$joined_paths:$CMAKE_PREFIX_PATH" ;;
    esac
  else
    export CMAKE_PREFIX_PATH="$joined_paths"
  fi

  echo "[flutter_with_cleanup] Prepending CMake prefix paths: $joined_paths" >&2
}

prepend_cmake_paths

configure_java_home() {
  local candidate_dir

  for candidate_dir in "$PROJECT_ROOT/.local-toolchain/root/usr/lib/jvm/java-21-openjdk-amd64" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib/jvm/java-21-openjdk-amd64"; do
    if [[ -d "$candidate_dir" ]]; then
      export JAVA_HOME="$(cd "$candidate_dir" && pwd -P)"
      case ":${PATH:-}:" in
        *":$JAVA_HOME/bin:"*) ;;
        *) export PATH="$JAVA_HOME/bin:$PATH" ;;
      esac
      echo "[flutter_with_cleanup] Configuring JAVA_HOME: $JAVA_HOME" >&2
      return 0
    fi
  done
}

configure_java_home

ensure_linker_wrappers() {
  local wrappers_dir
  local wrappers_root
  local linker_root

  for wrappers_dir in "$PROJECT_ROOT/.local-toolchain/wrappers" "$PROJECT_ROOT/../.local-toolchain/wrappers"; do
    if [[ -d "$wrappers_dir" ]]; then
      wrappers_root="$(cd "$wrappers_dir" && pwd -P)"
      break
    fi
  done

  for linker_root in "$PROJECT_ROOT/.local-toolchain/root/usr/bin" "$PROJECT_ROOT/../.local-toolchain/root/usr/bin"; do
    if [[ -d "$linker_root" ]]; then
      linker_root="$(cd "$linker_root" && pwd -P)"
      break
    fi
  done

  if [[ -z "${wrappers_root:-}" || -z "${linker_root:-}" ]]; then
    return 0
  fi

  link_tool() {
    local name="$1"
    local target="$2"
    if [[ ! -e "$wrappers_root/$name" && -e "$target" ]]; then
      ln -s "$target" "$wrappers_root/$name"
      echo "[flutter_with_cleanup] Linking linker wrapper: $wrappers_root/$name -> $target" >&2
    fi
  }

  link_tool ld "$linker_root/ld"
  link_tool ld.lld "$wrappers_root/ld"
  link_tool ld.lld-19 "$linker_root/ld.lld-19"
  link_tool ar "$linker_root/ar"
  link_tool llvm-ar "$wrappers_root/ar"
  link_tool ranlib "$linker_root/ranlib"
  link_tool llvm-ranlib "$wrappers_root/ranlib"
  link_tool strip "$linker_root/strip"
  link_tool llvm-strip "$wrappers_root/strip"
}

ensure_linker_wrappers

mirror_writable_project_root_if_needed() {
  local dart_tool_dir="$PROJECT_ROOT/.dart_tool"
  local mirror_root

  if [[ ! -d "$dart_tool_dir" || -w "$dart_tool_dir" ]]; then
    return 0
  fi

  if [[ -n "$MIRROR_PROJECT_ROOT" ]]; then
    PROJECT_ROOT="$MIRROR_PROJECT_ROOT"
    return 0
  fi

  mirror_root="$(mktemp -d "${TMPDIR:-/tmp}/flutter_with_cleanup.XXXXXX")"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude '.git' \
      --exclude '.pub-cache' \
      --exclude '.dart_tool' \
      --exclude '.flutter-plugins-dependencies' \
      --exclude '.packages' \
      "$SOURCE_PROJECT_ROOT/" \
      "$mirror_root/"
  else
    cp -a "$SOURCE_PROJECT_ROOT/." "$mirror_root/"
  fi

  chmod -R u+rwX "$mirror_root"

  if ! command -v rsync >/dev/null 2>&1; then
    rm -rf \
      "$mirror_root/.git" \
      "$mirror_root/.pub-cache" \
      "$mirror_root/.dart_tool" \
      "$mirror_root/.flutter-plugins-dependencies" \
      "$mirror_root/.packages"
  fi

  MIRROR_PROJECT_ROOT="$mirror_root"
  PROJECT_ROOT="$mirror_root"
  echo "[flutter_with_cleanup] Detected non-writable .dart_tool; using writable mirror workspace: $PROJECT_ROOT" >&2
}

configure_curl_paths() {
  local curl_library_candidate
  local curl_include_candidate

  for curl_library_candidate in "$PROJECT_ROOT/.local-toolchain/root/usr/lib/x86_64-linux-gnu/libcurl.so" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib/x86_64-linux-gnu/libcurl.so" "$PROJECT_ROOT/.local-toolchain/root/usr/lib/libcurl.so" "$PROJECT_ROOT/../.local-toolchain/root/usr/lib/libcurl.so"; do
    if [[ -f "$curl_library_candidate" ]]; then
      export CURL_LIBRARY="$(cd "$(dirname "$curl_library_candidate")" && pwd -P)/$(basename "$curl_library_candidate")"
      break
    fi
  done

  for curl_include_candidate in "$PROJECT_ROOT/.local-toolchain/root/usr/include/x86_64-linux-gnu" "$PROJECT_ROOT/../.local-toolchain/root/usr/include/x86_64-linux-gnu" "$PROJECT_ROOT/.local-toolchain/root/usr/include" "$PROJECT_ROOT/../.local-toolchain/root/usr/include"; do
    if [[ -d "$curl_include_candidate" ]]; then
      export CURL_INCLUDE_DIR="$(cd "$curl_include_candidate" && pwd -P)"
      break
    fi
  done

  if [[ -n "${CURL_LIBRARY:-}" || -n "${CURL_INCLUDE_DIR:-}" ]]; then
    echo "[flutter_with_cleanup] Configuring CURL library/include paths: ${CURL_LIBRARY:-unset} / ${CURL_INCLUDE_DIR:-unset}" >&2
  fi
}

configure_curl_paths

resolve_flutter_bin() {
  local candidates=(
    "${FLUTTER_BIN:-}"
    "$(command -v flutter 2>/dev/null || true)"
    "/mnt/data/flutter-sdk/bin/flutter"
    "/opt/flutter/bin/flutter"
    "$HOME/flutter/bin/flutter"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  echo "Unable to locate a Flutter binary. Set FLUTTER_BIN or install Flutter in PATH." >&2
  return 1
}

quarantine_plugin_symlinks() {
  local target_dir="$1"
  local target_name="$target_dir/.plugin_symlinks"

  if [[ ! -e "$target_name" ]]; then
    return 0
  fi

  if [[ -w "$target_name" ]]; then
    rm -rf "$target_name"
    return 0
  fi

  local quarantine_name="$target_name.quarantine.$(date +%s)"
  mv "$target_name" "$quarantine_name"
}

cleanup_flutter_generated_state() {
  local platform_dir
  for platform_dir in android ios linux macos windows web; do
    if [[ -d "$PROJECT_ROOT/$platform_dir/flutter/ephemeral" ]]; then
      quarantine_plugin_symlinks "$PROJECT_ROOT/$platform_dir/flutter/ephemeral"
    fi
  done
}

cleanup_stale_linux_cmake_cache() {
  local build_variant
  local build_dir
  local cache_file
  local recorded_home
  local recorded_cache_dir

  for build_variant in debug profile release; do
    build_dir="$PROJECT_ROOT/build/linux/x64/$build_variant"
    cache_file="$build_dir/CMakeCache.txt"

    if [[ ! -f "$cache_file" ]]; then
      continue
    fi

    recorded_home="$(grep '^CMAKE_HOME_DIRECTORY:INTERNAL=' "$cache_file" | cut -d= -f2- || true)"
    recorded_cache_dir="$(grep '^CMAKE_CACHEFILE_DIR:INTERNAL=' "$cache_file" | cut -d= -f2- || true)"

    if [[ "$recorded_home" != "$PROJECT_ROOT/linux" || "$recorded_cache_dir" != "$build_dir" ]]; then
      echo "[flutter_with_cleanup] Removing stale Linux CMake cache: $build_dir" >&2
      rm -rf "$build_dir"
      continue
    fi

    if grep -q '=/usr/include/' "$cache_file" || grep -q '=/usr/lib/x86_64-linux-gnu/' "$cache_file"; then
      echo "[flutter_with_cleanup] Removing host-pinned Linux CMake cache: $build_dir" >&2
      rm -rf "$build_dir"
    fi
  done
}

refresh_dart_package_config_if_needed() {
  local package_config="$PROJECT_ROOT/.dart_tool/package_config.json"
  local pub_get_requested=0
  local expected_pub_cache="$PUB_CACHE"
  local package_config_needs_refresh=0

  if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
    return 0
  fi

  if [[ -f "$package_config" ]]; then
    if ! grep -q "$expected_pub_cache" "$package_config"; then
      package_config_needs_refresh=1
    fi
  else
    package_config_needs_refresh=1
  fi

  if [[ "$package_config_needs_refresh" -eq 0 ]]; then
    if grep -q '/paperclip/.pub-cache' "$package_config" ||        grep -q '/mnt/data/projects/CloudToLocalLLM/.pub-cache' "$package_config" ||        grep -q '/paperclip/CloudToLocalLLM/.pub-cache' "$package_config" ||        grep -q '/workspace/.pub-cache' "$package_config"; then
      package_config_needs_refresh=1
    fi
  fi

  if [[ "$package_config_needs_refresh" -eq 0 ]]; then
    return 0
  fi

  mirror_writable_project_root_if_needed
  package_config="$PROJECT_ROOT/.dart_tool/package_config.json"

  echo "[flutter_with_cleanup] Refreshing Dart package config with PUB_CACHE=$PUB_CACHE" >&2
  rm -rf "$PROJECT_ROOT/.dart_tool" "$PROJECT_ROOT/.flutter-plugins-dependencies" "$PROJECT_ROOT/.packages"
  (cd "$PROJECT_ROOT" && "$FLUTTER_BIN_PATH" pub get)
}

mirror_writable_project_root_if_needed
cleanup_flutter_generated_state
cleanup_stale_linux_cmake_cache

FLUTTER_BIN_PATH="$(resolve_flutter_bin)"
refresh_dart_package_config_if_needed "$@"
(cd "$PROJECT_ROOT" && "$FLUTTER_BIN_PATH" "$@")
