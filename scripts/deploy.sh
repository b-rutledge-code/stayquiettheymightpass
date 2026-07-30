#!/bin/bash
# Deploy Stay Quiet, They Might Pass to local Zomboid mods folder for testing.
# Run from repo root or from mod root (scripts/deploy.sh).

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOD_ROOT="$(dirname "$SCRIPT_DIR")"
MOD_NAME="stayquiettheymightpass"
ZOMBOID_DIR="${ZOMBOID_DIR:-$HOME/Zomboid/mods}"
DEST_DIR="$ZOMBOID_DIR/$MOD_NAME"

echo -e "${GREEN}=== Stay Quiet, They Might Pass — deploy ===${NC}"

if [ ! -d "$ZOMBOID_DIR" ]; then
    echo -e "${RED}Zomboid mods directory not found: $ZOMBOID_DIR${NC}"
    echo "Run the game at least once or set ZOMBOID_DIR."
    exit 1
fi

if [ ! -d "$MOD_ROOT/42.20" ]; then
    echo -e "${RED}Mod source not found: $MOD_ROOT/42.20${NC}"
    exit 1
fi

if [ -d "$DEST_DIR" ]; then
    echo -e "${YELLOW}Removing old version...${NC}"
    rm -rf "$DEST_DIR"
fi

mkdir -p "$DEST_DIR"
echo -e "${YELLOW}Copying mod files...${NC}"
cp -r "$MOD_ROOT/42.20" "$DEST_DIR/"

echo -e "${GREEN}Mod deployed to: $DEST_DIR${NC}"
echo ""
echo -e "${YELLOW}Next: enable 'Stay Quiet, They Might Pass' in game Mods, then restart.${NC}"
