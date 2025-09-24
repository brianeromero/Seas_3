#!/bin/bash
set -e

echo "🏗️ Prebuild: CocoaPods install (skipped if handled by Xcode Cloud)"

# Navigate to the repo root
cd "$XCODE_WORKSPACE_DIR" || exit 1

# Only install Pods if they do NOT exist
if [ ! -d "Pods" ]; then
  echo "📦 Pods folder not found — installing..."
  rm -rf ~/Library/Caches/CocoaPods
  pod install --repo-update
else
  echo "📦 Pods folder exists — skipping install (Xcode Cloud should handle it)"
fi

echo "✅ Prebuild complete"
