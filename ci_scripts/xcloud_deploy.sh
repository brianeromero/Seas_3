#!/bin/bash
set -euo pipefail

# Default SRCROOT to current directory if not set by Xcode
SRCROOT="${SRCROOT:-$(pwd)}"

APP_NAME="Seas_3"
SCHEME_NAME="Seas_3"
EXPORT_OPTIONS_PLIST="ExportOptions.plist"
BUILD_PATH="$SRCROOT/build"
ARCHIVE_PATH="$BUILD_PATH/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_PATH/Export"

echo "🏗️ Starting build & archive for $APP_NAME..."
cd "$SRCROOT" || exit 1

# Check that Pods folder exists (skip .xcconfig check — Xcode Cloud handles it)
if [ ! -d "Pods" ]; then
  echo "⚠️ Pods folder not found — Xcode Cloud should handle this."
else
  echo "✅ Pods folder exists"
fi

echo "2. Cleaning up previous builds..."
rm -rf "$BUILD_PATH"
mkdir -p "$BUILD_PATH"

echo "3. Building and archiving..."
xcodebuild archive \
  -workspace "$APP_NAME.xcworkspace" \
  -scheme "$SCHEME_NAME" \
  -configuration "Release" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  ONLY_ACTIVE_ARCH=NO \
  SKIP_INSTALL=NO

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "❌ Error: Archiving failed."
  exit 1
fi

echo "4. Exporting archive..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

if [ ! -d "$EXPORT_PATH" ]; then
  echo "❌ Error: Exporting failed."
  exit 1
fi

echo "✅ Build and export successful: $EXPORT_PATH"
