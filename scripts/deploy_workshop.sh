#!/bin/bash
# Deploy Stay Quiet to Workshop staging for the in-game uploader.
# PZwiki: ~/Zomboid/Workshop/<name>/Contents/mods/<name>/... + workshop.txt + preview.png
#
# Usage:
#   ./scripts/deploy_workshop.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET_DIR="$HOME/Zomboid/Workshop"
WORKSHOP_MOD="$TARGET_DIR/stayquiettheymightpass"
CONTENTS_MOD="$WORKSHOP_MOD/Contents/mods/stayquiettheymightpass"

if [ ! -d "$PROJECT_ROOT/42.20" ]; then
    echo "❌ Mod source not found: $PROJECT_ROOT/42.20"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/workshop.txt" ]; then
    echo "❌ Missing workshop.txt at mod root"
    exit 1
fi

if [ -d "$WORKSHOP_MOD" ]; then
    echo "🗑️  Removing existing Workshop mod directory..."
    rm -rf "$WORKSHOP_MOD"
fi

echo "📂 Creating Workshop structure..."
mkdir -p "$CONTENTS_MOD"

if [ -d "$PROJECT_ROOT/common" ]; then
    cp -r "$PROJECT_ROOT/common" "$CONTENTS_MOD/"
else
    mkdir -p "$CONTENTS_MOD/common"
fi

echo "📦 Copying 42.20..."
cp -r "$PROJECT_ROOT/42.20" "$CONTENTS_MOD/"

cp "$PROJECT_ROOT/workshop.txt" "$WORKSHOP_MOD/"
if [ -f "$PROJECT_ROOT/preview.png" ]; then
    cp "$PROJECT_ROOT/preview.png" "$WORKSHOP_MOD/"
else
    echo "⚠️  No preview.png at mod root — add one for the Workshop thumb"
fi

echo "🧹 Cleaning up..."
find "$WORKSHOP_MOD" -name ".DS_Store" -delete

echo "✅ Deployed to $WORKSHOP_MOD"
echo "   Structure: Contents/mods/stayquiettheymightpass/{common,42.20}"
echo "   Next: Run game → Workshop → Create and update items"
