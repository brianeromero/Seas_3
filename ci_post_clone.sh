#!/bin/bash
set -euo pipefail
set -x

echo "🏗️ Starting CocoaPods install for Xcode Cloud..."

# Add Homebrew Ruby gem bin directories to PATH (where pod lives)
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Use SRCROOT as default if not set
ROOT="${XCODE_WORKSPACE_DIR:-${SRCROOT:-$(pwd)}}"
cd "$ROOT" || { echo "❌ Failed to cd into $ROOT"; exit 1; }

# Remove cache to ensure clean install on CI
echo "🧹 Cleaning CocoaPods cache..."
rm -rf ~/Library/Caches/CocoaPods

# Install pods
echo "📦 Installing pods..."
pod install --repo-update --verbose

echo "✅ CocoaPods install completed successfully"
