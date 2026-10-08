#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
base_path="${BONYE_WEB_BASE_PATH:-/app/}"
flutter pub get --enforce-lockfile
flutter build web --release --pwa-strategy=none --no-web-resources-cdn --base-href "$base_path"
python3 tool/prepare_pwa.py
