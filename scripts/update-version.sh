#!/bin/bash

# Update version script for Xcode project
# Usage: ./scripts/update-version.sh <new_version>

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <new_version>"
  echo "Example: $0 1.0.0"
  exit 1
fi

NEW_VERSION="$1"
PROJECT_FILE="open-sidenotes.xcodeproj/project.pbxproj"

echo "Updating MARKETING_VERSION to $NEW_VERSION in $PROJECT_FILE..."

# Update only the first two occurrences (main target, Debug and Release configs)
# macOS sed requires -i with empty string for in-place editing
if [[ "$OSTYPE" == "darwin"* ]]; then
  # Update line 417 and 442 (main target configurations)
  sed -i '' "417s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/" "$PROJECT_FILE"
  sed -i '' "442s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/" "$PROJECT_FILE"
else
  sed -i "417s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/" "$PROJECT_FILE"
  sed -i "442s/MARKETING_VERSION = .*;/MARKETING_VERSION = $NEW_VERSION;/" "$PROJECT_FILE"
fi

echo "✅ Version updated successfully!"
echo ""
echo "Updated lines:"
grep -n "MARKETING_VERSION = $NEW_VERSION" "$PROJECT_FILE" | head -2
