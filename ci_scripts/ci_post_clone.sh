#!/bin/sh
set -euo pipefail

# Files to patch (relative to project root)
FILES=(
  "Pods/gRPC-Core/src/core/lib/promise/detail/basic_seq.h"
  "Pods/gRPC-C++/src/core/lib/promise/detail/basic_seq.h"
)

for FILE in "${FILES[@]}"; do
  echo "🔧 Attempting to patch $FILE..."

  if [ ! -f "$FILE" ]; then
    echo "⚠️ File not found: $FILE — skipping."
    continue
  fi

  # Ensure file is writable
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
