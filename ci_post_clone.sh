#!/bin/bash
set -euo pipefail
set -x

echo "🏗️ Starting CocoaPods install for Xcode Cloud..."

# Ensure pod command is available
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Navigate to workspace root
ROOT="${XCODE_WORKSPACE_DIR:-${SRCROOT:-$(pwd)}}"
cd "$ROOT" || { echo "❌ Failed to cd into $ROOT"; exit 1; }

# Clean CocoaPods cache to ensure reproducible builds
echo "🧹 Cleaning CocoaPods cache..."
rm -rf ~/Library/Caches/CocoaPods

# Install pods fresh
echo "📦 Installing pods..."
pod install --repo-update --clean-install --verbose

echo "✅ CocoaPods install completed successfully"
