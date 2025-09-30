#!/bin/sh
set -eo pipefail

# Ensure PATH is correct inside Xcode/CI
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "--- STARTING COCOAPODS AND PATCH SCRIPT (UNIFIED) ---"

# Track actions for summary
PATCHED_FILES=()
SKIPPED_FILES=()

# --- 0. DETECT MODE ---
# Default: fast (local dev). If CI=true or FORCE_CLEAN=true → clean mode.
CLEAN_MODE=false
if [ "$CI" = "true" ] || [ "$FORCE_CLEAN" = "true" ]; then
  CLEAN_MODE=true
fi

# --- 1. NAVIGATE TO PROJECT DIR ---
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT/Seas_3" || { echo "❌ Failed to cd into project dir"; exit 2; }

# --- 2. CLEAN OR FAST INSTALL ---
if [ "$CLEAN_MODE" = true ]; then
  echo "🧹 Running in CLEAN mode (CI or FORCE_CLEAN)"
  rm -rf "$HOME/Library/Caches/CocoaPods"
  rm -rf "Pods"
  rm -f "Podfile.lock"
  echo "Running pod install (clean install)"
  pod install --repo-update --clean-install --no-ansi
else
  echo "⚡ Running in FAST mode (local dev, cached Pods)"
  pod install --repo-update --no-ansi
fi

echo "✅ Pod install complete."

# --- 3. GRPC PATCHING ---
FILE1="Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
FILE2="Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"

for FILE in "$FILE1" "$FILE2"; do
    echo "🔧 Checking and patching $FILE..."
    if [ -f "$FILE" ]; then
        chmod u+w "$FILE"
        sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE"
        PATCHED_FILES+=("$FILE")
        echo "✅ Patch applied to $FILE"
    else
        SKIPPED_FILES+=("$FILE")
        echo "⚠️ File $FILE not found (skipping)."
    fi
done

# --- 4. SUMMARY ---
echo ""
echo "================== SUMMARY =================="
if [ "$CLEAN_MODE" = true ]; then
  echo "Mode: 🧹 CLEAN (fresh Pods install)"
else
  echo "Mode: ⚡ FAST (cached Pods)"
fi

# Show Podfile.lock checksum (useful for debugging state)
if [ -f "Podfile.lock" ]; then
  LOCKSUM=$(shasum Podfile.lock | awk '{print $1}')
  echo "Podfile.lock checksum: $LOCKSUM"
else
  echo "Podfile.lock not found."
fi

# Show patched files
if [ ${#PATCHED_FILES[@]} -gt 0 ]; then
  echo "Patched files:"
  for f in "${PATCHED_FILES[@]}"; do
    echo "  ✅ $f"
  done
else
  echo "No files patched."
fi

# Show skipped files
if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
  echo "Skipped files (not found):"
  for f in "${SKIPPED_FILES[@]}"; do
    echo "  ⚠️ $f"
  done
fi

echo "============================================="
echo "🎉 Script completed successfully."
echo ""
exit 0
