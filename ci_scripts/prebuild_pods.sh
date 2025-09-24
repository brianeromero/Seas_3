#!/bin/bash
set -e

echo "🏗️ Prebuild: CocoaPods install"

# Navigate to the repo root
cd "$XCODE_WORKSPACE_DIR" || exit 1

# Install Pods every time (to make sure Target Support Files exist)
rm -rf ~/Library/Caches/CocoaPods
pod install --repo-update

echo "✅ Prebuild complete"
