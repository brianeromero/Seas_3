#!/bin/bash
set -euo pipefail

echo "🏗️ Prebuild: CocoaPods install"

# Add Ruby gem bin directory to PATH (where pod lives locally)
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Pick the correct root depending on local vs Xcode Cloud
if [ -n "${XCODE_WORKSPACE_DIR:-}" ]; then
  ROOT="$XCODE_WORKSPACE_DIR"
  echo "📂 Detected Xcode Cloud environment → Using XCODE_WORKSPACE_DIR: $ROOT"
else
  ROOT="$SRCROOT"
  echo "📂 Detected local Xcode build → Using SRCROOT: $ROOT"
fi

cd "$ROOT" || { echo "❌ Failed to cd into $ROOT"; exit 1; }

# Install Pods every time (ensures Target Support Files exist in Cloud)
echo "📦 Running pod install --repo-update..."
rm -rf ~/Library/Caches/CocoaPods
pod install --repo-update

echo "✅ Prebuild complete at $ROOT"
