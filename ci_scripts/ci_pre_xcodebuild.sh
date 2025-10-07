#!/bin/bash
set -euo pipefail
set -x

echo "🏗️ Starting CocoaPods install for Xcode Cloud..."

# Ensure 'pod' is in PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"

# Navigate to workspace root
cd "${CI_WORKSPACE:-${SRCROOT:-$(pwd)}}" || { echo "❌ Failed to cd into workspace"; exit 1; }

# Clean CocoaPods cache for reproducible builds
echo "🧹 Cleaning CocoaPods cache..."
rm -rf Pods/ && rm -rf "${HOME}/Library/Caches/CocoaPods"

# Install pods fresh
echo "📦 Installing pods..."
pod install --repo-update --clean-install --verbose

echo "✅ CocoaPods install completed successfully"
