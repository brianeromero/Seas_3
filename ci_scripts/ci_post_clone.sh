#!/bin/bash
set -euo pipefail
set -x

echo "🏗️ Post-clone setup for Xcode Cloud..."

# Ensure 'pod' is in PATH for any future scripts/tools
export PATH="/usr/local/bin:/opt/homebrew/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"

# Navigate to workspace root
ROOT="${XCODE_WORKSPACE_DIR:-${SRCROOT:-$(pwd)}}"
cd "$ROOT" || { echo "❌ Failed to cd into $ROOT"; exit 1; }

echo "✅ Post-clone environment setup complete"

# Note: CocoaPods install is handled in ci_pre_xcodebuild.sh to avoid duplication
