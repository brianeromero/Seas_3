#!/bin/sh
# Set -e is good, but -u (unset variables fail) can cause problems. Let's loosen slightly.
set -eo pipefail

echo "--- STARTING COCOAPODS AND PATCH SCRIPT ---"

# --- 1. COCOAPODS INSTALL ---
# CI_WORKSPACE is the absolute path to the root of the entire cloned repository environment.
# We explicitly use it to ensure the path is absolute and correct.
REPO_ROOT="${CI_WORKSPACE}"

# Construct the correct absolute path to the project directory
# We assume the Podfile is inside a folder named 'Seas_3' relative to the workspace root.
PROJECT_DIR="${REPO_ROOT}/Seas_3" # <--- THIS IS THE KEY CHANGE (using CI_WORKSPACE)

# Navigate directly to the Podfile location
echo "Navigating to Podfile directory: $PROJECT_DIR"
cd "$PROJECT_DIR" || { echo "❌ Failed to change directory to $PROJECT_DIR"; exit 2; }

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

# --- 2. GRPC PATCHING LOGIC ---
echo "--- Starting gRPC Patching ---"

# Files to patch (paths are relative to the current working directory, which is now the Seas_3 folder)
FILES=(
  "Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
  "Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"
)

for FILE in "${FILES[@]}"; do
  echo "🔧 Attempting to patch $FILE..."

  # Check if the file exists after pod install
  if [ ! -f "$FILE" ]; then
    echo "⚠️ Patch target file not found after pod install: $FILE — skipping."
    continue
  fi

  # Ensure file is writable (this is critical after pod install)
  chmod u+w "$FILE"

  # Create a backup first
  cp "$FILE" "$FILE.bak"

  # Use sed (macOS-friendly) to patch
  sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE"

  # Verify the change
  if grep -q "Traits::CallSeqFactory" "$FILE"; then
    echo "✅ Patched $FILE successfully."
  else
    echo "⚠️ Patch did not apply correctly to $FILE."
    # Do not exit here; let the rest of the script/build run if possible
  fi

done

echo "🎉 Script completed successfully."

exit 0
