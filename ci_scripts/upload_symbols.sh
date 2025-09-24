#!/bin/sh
set -e

# Fallback for SRCROOT if running outside Xcode
: "${SRCROOT:=$(pwd)}"

# Fallback for dSYM paths (these exist only during archive)
: "${DWARF_DSYM_FOLDER_PATH:=}"
: "${DWARF_DSYM_FILE_NAME:=}"

# Skip if dSYM info is missing (common for local builds)
if [ -z "$DWARF_DSYM_FOLDER_PATH" ] || [ -z "$DWARF_DSYM_FILE_NAME" ]; then
  echo "⚠️  Skipping upload-symbols: dSYM not found (likely local build)"
  exit 0
fi

# Locate upload-symbols in Pods
UPLOAD_SYMBOLS="$SRCROOT/Pods/FirebaseCrashlytics/upload-symbols"

if [ ! -f "$UPLOAD_SYMBOLS" ]; then
  echo "❌ upload-symbols not found at $UPLOAD_SYMBOLS"
  exit 1
fi

# Verify GoogleService-Info.plist exists
if [ ! -f "${PROJECT_DIR}/GoogleService-Info.plist" ]; then
  echo "❌ GoogleService-Info.plist not found at ${PROJECT_DIR}/GoogleService-Info.plist"
  exit 1
fi

echo "✅ Found upload-symbols at $UPLOAD_SYMBOLS"
echo "📤 Uploading dSYM..."
"$UPLOAD_SYMBOLS" -gsp "${PROJECT_DIR}/GoogleService-Info.plist" -p ios "$DWARF_DSYM_FOLDER_PATH/$DWARF_DSYM_FILE_NAME"
echo "✅ dSYM upload complete"
