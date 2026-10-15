#!/usr/bin/env bash
# Renders the menu UI to docs/menu.png (light) and docs/menu-dark.png.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -parse-as-library -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos12.0" \
    $(ls Sources/*.swift | grep -v WheresMyMouseApp.swift) scripts/snapshot/main.swift -o build/snapshot-menu
build/snapshot-menu docs/menu.png
build/snapshot-menu docs/menu-dark.png --dark
