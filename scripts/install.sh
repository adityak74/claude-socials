#!/usr/bin/env sh
# install.sh — add the claude-socials marketplace and install a plugin
#
# Usage:
#   install.sh                        # add the marketplace only
#   install.sh <plugin-id>            # add marketplace + install plugin
#   install.sh <plugin-id> --scope project   # install at project scope

set -e

MARKETPLACE="adityak74/claude-socials"
PLUGIN_ID="$1"
SCOPE=""

shift 2>/dev/null || true
for arg in "$@"; do
  case "$arg" in
    --scope) SCOPE="$2"; shift ;;
    --scope=*) SCOPE="${arg#--scope=}" ;;
  esac
done

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: Claude Code CLI ('claude') is not installed or not in PATH."
  echo "Install Claude Code from https://claude.ai/code"
  exit 1
fi

echo "Adding claude-socials marketplace..."
claude plugin marketplace add "$MARKETPLACE"
echo ""

if [ -n "$PLUGIN_ID" ]; then
  if [ -n "$SCOPE" ]; then
    echo "Installing plugin: $PLUGIN_ID (scope: $SCOPE)..."
    claude plugin install "${PLUGIN_ID}@claude-socials" --scope "$SCOPE"
  else
    echo "Installing plugin: $PLUGIN_ID..."
    claude plugin install "${PLUGIN_ID}@claude-socials"
  fi
  echo ""
  echo "Done. Restart Claude Code to activate the plugin."
  echo ""
  echo "Usage inside Claude Code:"
  echo "  /$PLUGIN_ID"
else
  echo "Marketplace added. Install a plugin with:"
  echo "  claude plugin install <plugin-id>@claude-socials"
  echo ""
  echo "Available plugins:"
  echo "  hn-submit   — Submit to Hacker News"
fi
