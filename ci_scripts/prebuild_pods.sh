#!/bin/bash
set -euo pipefail

echo "🏗️ Prebuild: CocoaPods check"

# Add Ruby gem bin directory to PATH (where pod lives locally)
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Use SRCROOT as default if XCODE_WORKSPACE_DIR is not set
ROOT="${XCODE_WORKSPACE_DIR:-${SRCROOT:-$(pwd)}}"
cd "$ROOT" || { echo "❌ Failed to cd into $ROOT"; exit 1; }

# Detect CI/Xcode Cloud
if [ "${CI:-}" = "true" ]; then
  echo "☁️ CI/Xcode Cloud detected → Running pod install --repo-update..."
  rm -rf ~/Library/Caches/CocoaPods
  pod install --repo-update
else
  echo "💻 Local build detected → Skipping pod install (manual pod install is recommended locally if needed)"
fi

echo "✅ Prebuild complete at $ROOT"
