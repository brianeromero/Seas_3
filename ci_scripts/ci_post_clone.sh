#!/bin/sh
# Fail the build if any command fails
set -euo pipefail

# ----------------------------------------------------
# 1. COCOAPODS INSTALL (REQUIRED FOR XCODE CLOUD)
# ----------------------------------------------------
echo "📦 Starting pod install to generate configuration files..."

# Find the directory containing the Podfile
# We assume the Podfile is either in the repository root or immediately below it.
PODFILE_DIR=$(find "${CI_PRIMARY_REPO_PATH}" -name "Podfile" -exec dirname {} \;)

if [ -z "$PODFILE_DIR" ]; then
    echo "❌ Error: Podfile not found in the repository. Check path."
    exit 1
fi

# Navigate to the directory containing the Podfile
echo "Navigating to Podfile directory: $PODFILE_DIR"
cd "$PODFILE_DIR"

# Execute pod install using the standard Xcode Cloud path
# We use xcrun to ensure the correct environment and --clean-install for safety
/usr/bin/xcrun pod install --repo-update --clean-install

echo "✅ Pod install complete."
# ----------------------------------------------------


# ----------------------------------------------------
# 2. GRPC PATCHING LOGIC
# ----------------------------------------------------
# Files to patch (relative to the Podfile directory, which is now the current working directory)
FILES=(
  "Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
  "Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"
)

for FILE in "${FILES[@]}"; do
  echo "🔧 Attempting to patch $FILE..."

  if [ ! -f "$FILE" ]; then
    echo "⚠️ File not found: $FILE — skipping (this is expected if pod install failed)."
    continue
  fi

  # Ensure file is writable (this is critical after pod install)
  if [ ! -w "$FILE" ]; then
    echo "🔒 $FILE not writable. Fixing permissions..."
    chmod u+w "$FILE"
  fi

  # Create a backup first
  cp "$FILE" "$FILE.bak"

  # Use sed (macOS-friendly) to patch
  sed -i '' 's/Traits::template CallSeqFactory/Traits::CallSeqFactory/g' "$FILE"

  # Verify the change
  if grep -q "Traits::CallSeqFactory" "$FILE"; then
    echo "✅ Patched $FILE successfully (backup at $FILE.bak)"
  else
    echo "⚠️ Patch did not apply correctly — inspect $FILE and $FILE.bak"
  fi

done

echo "🎉 Patch process completed."
