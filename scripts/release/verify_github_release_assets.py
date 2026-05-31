#!/usr/bin/env python3
"""Verify GitHub release assets for a CloudToLocalLLM release.

The script polls the GitHub release API until the expected Windows and Linux
artifacts are visible or a retry budget is exhausted.

Environment:
  GITHUB_TOKEN            GitHub token used for API authentication
  GITHUB_REPOSITORY       Repository in owner/name form
  RELEASE_TAG             Release tag to inspect (e.g. v10.1.201)
  VERSION                 Semantic version (e.g. 10.1.201)
  GITHUB_API_BASE_URL     Optional API base (default: https://api.github.com)
  RETRY_ATTEMPTS          Optional retry count (default: 6)
  RETRY_DELAY_SECONDS     Optional delay between retries (default: 10)
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request


def _env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None or value == "":
        print(f"Missing required environment variable: {name}", file=sys.stderr)
        raise SystemExit(2)
    return value


def _int_env(name: str, default: str, minimum: int) -> int:
    raw_value = os.environ.get(name, default)
    try:
        value = int(raw_value)
    except ValueError:
        print(f"Invalid integer for {name}: {raw_value}", file=sys.stderr)
        raise SystemExit(2)
    if value < minimum:
        print(f"{name} must be >= {minimum}: {value}", file=sys.stderr)
        raise SystemExit(2)
    return value


def _release_url(api_base: str, repo: str, release_tag: str) -> str:
    return f"{api_base.rstrip('/')}/repos/{repo}/releases/tags/{release_tag}"


def main() -> int:
    token = _env("GITHUB_TOKEN")
    repo = _env("GITHUB_REPOSITORY")
    release_tag = _env("RELEASE_TAG")
    version = _env("VERSION")
    api_base = os.environ.get("GITHUB_API_BASE_URL", "https://api.github.com")
    retry_attempts = _int_env("RETRY_ATTEMPTS", "6", 1)
    retry_delay_seconds = _int_env("RETRY_DELAY_SECONDS", "10", 0)

    url = _release_url(api_base, repo, release_tag)
    required_assets = {
        f"cloudtolocalllm-{version}-portable.zip",
        f"cloudtolocalllm-{version}-portable.zip.sha256",
        f"CloudToLocalLLM-Windows-{version}-Setup.exe",
        f"CloudToLocalLLM-Windows-{version}-Setup.exe.sha256",
        f"cloudtolocalllm_{version}_amd64.deb",
        f"cloudtolocalllm_{version}_amd64.deb.sha256",
        f"cloudtolocalllm-{version}-x86_64.AppImage",
        f"cloudtolocalllm-{version}-x86_64.AppImage.sha256",
    }

    last_error: Exception | None = None
    for attempt in range(1, retry_attempts + 1):
        try:
            request = urllib.request.Request(
                url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                },
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                release = json.load(response)

            asset_names = {asset["name"] for asset in release.get("assets", [])}
            missing = sorted(required_assets - asset_names)
            if not missing:
                print("Verified GitHub release assets: " + ", ".join(sorted(required_assets)))
                return 0

            last_error = RuntimeError("Missing release assets: " + ", ".join(missing))
        except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as exc:
            last_error = exc

        if attempt < retry_attempts:
            time.sleep(retry_delay_seconds)

    print(str(last_error), file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
