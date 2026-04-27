#!/usr/bin/env sh
# install.sh — install a claude-socials skill into .claude/skills/
#
# Usage:
#   install.sh <skill-id>            # install into ./.claude/skills/
#   install.sh <skill-id> --global   # install into ~/.claude/skills/

set -e

REPO="https://github.com/adityak74/claude-socials"
RAW="https://raw.githubusercontent.com/adityak74/claude-socials/main"
TMP_DIR=$(mktemp -d)

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

SKILL_ID="$1"
GLOBAL=0

if [ -z "$SKILL_ID" ]; then
  echo "Usage: install.sh <skill-id> [--global]"
  echo ""
  echo "Available skills:"
  echo "  hn-submit   — Submit to Hacker News"
  exit 1
fi

shift
for arg in "$@"; do
  case "$arg" in
    --global) GLOBAL=1 ;;
  esac
done

if [ "$GLOBAL" = "1" ]; then
  DEST="$HOME/.claude/skills/$SKILL_ID"
else
  DEST=".claude/skills/$SKILL_ID"
fi

echo "Installing skill: $SKILL_ID"
echo "Destination: $DEST"
echo ""

# Fetch the SKILL.md via curl or wget
SKILL_URL="$RAW/skills/$SKILL_ID/SKILL.md"
SKILL_DST="$TMP_DIR/SKILL.md"

if command -v curl >/dev/null 2>&1; then
  HTTP_STATUS=$(curl -fsSL -o "$SKILL_DST" -w "%{http_code}" "$SKILL_URL")
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$SKILL_DST" "$SKILL_URL"
  HTTP_STATUS=200
else
  echo "Error: curl or wget is required."
  exit 1
fi

if [ ! -s "$SKILL_DST" ]; then
  echo "Error: skill '$SKILL_ID' not found in the marketplace."
  echo "Check available skills at $REPO"
  exit 1
fi

mkdir -p "$DEST"
cp "$SKILL_DST" "$DEST/SKILL.md"

echo "Skill installed successfully."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (or reload the window) to pick up the new skill."
echo "  2. Check the skill's README for required env vars and prerequisites:"
echo "     $REPO/tree/main/skills/$SKILL_ID"
echo ""
echo "To uninstall: rm -rf $DEST"
