#!/bin/sh
set -eo pipefail

echo "--- STARTING COCOAPODS AND PATCH SCRIPT ---"

# --- 1. COCOAPODS INSTALL ---
# Use the directory of the currently executing script ($0) to find the repo root
# The repository root is one level up from the 'ci_scripts' folder
REPO_ROOT=$(dirname "$0")/..

# Navigate to the repository root first
echo "Navigating to repository root: $REPO_ROOT"
cd "$REPO_ROOT" || { echo "❌ Failed to change directory to repository root: $REPO_ROOT"; exit 2; }
REPO_ROOT=$(pwd) # Get the absolute, canonical path

# Now construct and navigate into the project folder
PROJECT_DIR="${REPO_ROOT}/Seas_3"
echo "Navigating to Podfile directory: $PROJECT_DIR"
cd "$PROJECT_DIR" || { echo "❌ Failed to change directory to project directory: $PROJECT_DIR"; exit 2; }

# Important: Clear the local cache to prevent stale repo/dependency issues
echo "Clearing CocoaPods local cache to ensure a fresh install."
rm -rf "$HOME/Library/Caches/CocoaPods"
rm -rf "Pods"
rm -f "Podfile.lock"

# Execute pod install with --repo-update to get the latest specs,
# --clean-install to ensure a fresh, non-incremental build,
# and --no-ansi to avoid terminal formatting issues.
echo "Running /usr/bin/xcrun pod install --repo-update --clean-install --no-ansi"
/usr/bin/xcrun pod install --repo-update --clean-install --no-ansi

if [ $? -ne 0 ]; then
    echo "❌ CRITICAL ERROR: 'pod install' failed. Check the log above for dependency resolution errors."
    exit 1
fi

echo "✅ Pod install complete. Dependencies are in the 'Pods' folder."

# --- 2. GRPC PATCHING LOGIC (SAFE VERSION) ---
echo "--- Starting gRPC Patching (Direct Execution) ---"

# The project is currently CD'd into the 'Seas_3' directory.
# Apply the sed command directly to the necessary files within the Pods folder.

FILE1="Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
FILE2="Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"

echo "🔧 Patching $FILE1..."
# Ensure writability and apply patch
chmod u+w "$FILE1"
sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE1"

echo "🔧 Patching $FILE2..."
# Ensure writability and apply patch
chmod u+w "$FILE2"
sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE2"

echo "✅ gRPC Patching complete."
# --- END GRPC PATCHING LOGIC ---

echo "🎉 Script completed successfully."

exit 0
