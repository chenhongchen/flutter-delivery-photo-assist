#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk_root" && -f "$project_root/android/local.properties" ]]; then
  while IFS= read -r line; do
    case "$line" in sdk.dir=*) sdk_root="${line#sdk.dir=}" ;; esac
  done < "$project_root/android/local.properties"
fi
if [[ -n "$sdk_root" ]]; then
  export ANDROID_HOME="$sdk_root"
  if ! command -v cmake >/dev/null 2>&1; then
    for candidate in "$sdk_root"/cmake/*/bin; do
      if [[ -x "$candidate/cmake" ]]; then export PATH="$candidate:$PATH"; fi
    done
  fi
fi
if ! command -v cmake >/dev/null 2>&1; then
  echo 'OpenCV Native Assets needs CMake. Install CMake/Ninja or set ANDROID_HOME to your Android SDK.' >&2
  exit 1
fi
cd "$project_root"
exec flutter "$@"
