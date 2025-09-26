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
echo "Current working directory for patch: $(pwd)"
echo "Repository root: $REPO_ROOT" # <-- Added sanity check for root

# Check if Pods were created in the current directory (Seas_3) or the repository root.
# Construct absolute paths relative to the repository root for robustness.

# Assume Pods are at the REPO_ROOT (one level up from where we are now)
# NOTE: If this path is still wrong, we'll try the old relative path next.
FILE1="${REPO_ROOT}/Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
FILE2="${REPO_ROOT}/Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"

# --- Patch File 1 ---
echo "🔧 Checking and Patching $FILE1..."
if [ -f "$FILE1" ]; then
    # Ensure writability and apply patch
    chmod u+w "$FILE1"
    sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE1"
    echo "✅ Patch applied to $FILE1."
else
    echo "❌ CRITICAL ERROR: Patch target $FILE1 not found at REPO_ROOT/Pods. Trying relative path..."

    # Fallback to the original relative path (just in case the path is wrong)
    FILE1_REL="Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
    if [ -f "$FILE1_REL" ]; then
        chmod u+w "$FILE1_REL"
        sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE1_REL"
        echo "✅ Patch applied using relative path."
    else
        echo "❌ CRITICAL ERROR: Could not find $FILE1 or $FILE1_REL. Cannot proceed."
        exit 3
    fi
fi

# --- Patch File 2 ---
echo "🔧 Checking and Patching $FILE2..."
# Using the new absolute path for the second file
FILE2="${REPO_ROOT}/Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"

if [ -f "$FILE2" ]; then
    # Ensure writability and apply patch
    chmod u+w "$FILE2"
    sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE2"
    echo "✅ Patch applied to $FILE2."
else
    echo "❌ CRITICAL ERROR: Patch target $FILE2 not found at REPO_ROOT/Pods. Trying relative path..."
    
    # Fallback to the original relative path
    FILE2_REL="Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"
    if [ -f "$FILE2_REL" ]; then
        chmod u+w "$FILE2_REL"
        sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE2_REL"
        echo "✅ Patch applied using relative path."
    else
        echo "❌ CRITICAL ERROR: Could not find $FILE2 or $FILE2_REL. Cannot proceed."
        exit 3
    fi
fi


echo "✅ gRPC Patching complete."
# --- END GRPC PATCHING LOGIC ---

echo "🎉 Script completed successfully."

exit 0
