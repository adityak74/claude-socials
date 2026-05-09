#!/usr/bin/env sh
# install.sh — install claude-socials skills into Claude Code, Codex, and/or Hermes
#
# Usage:
#   install.sh                                  # add marketplace / detect all agents
#   install.sh <plugin-id>                      # install plugin into all detected agents
#   install.sh <plugin-id> --agent claude       # install into Claude Code only
#   install.sh <plugin-id> --agent codex        # install into Codex only
#   install.sh <plugin-id> --agent hermes       # install into Hermes only
#   install.sh <plugin-id> --agent all          # install into all detected agents
#   install.sh <plugin-id> --scope project      # Claude Code: install at project scope
#
# Agents:
#   Claude Code  — https://claude.ai/code
#   OpenAI Codex — https://developers.openai.com/codex
#   Hermes Agent — https://hermes-agent.nousresearch.com

set -e

MARKETPLACE="adityak74/claude-socials"
REPO_URL="https://github.com/adityak74/claude-socials.git"
CLONE_DIR="$HOME/.claude-socials"
PLUGIN_ID=""
AGENT_FILTER=""
SCOPE=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
if [ -n "$1" ] && [ "${1#-}" = "$1" ]; then
  PLUGIN_ID="$1"
  shift
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --agent)   AGENT_FILTER="$2"; shift 2 ;;
    --agent=*) AGENT_FILTER="${1#--agent=}"; shift ;;
    --scope)   SCOPE="$2"; shift 2 ;;
    --scope=*) SCOPE="${1#--scope=}"; shift ;;
    --help|-h)
      sed -n '2,14p' "$0"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Normalize --agent all → empty string (means: detect all)
[ "$AGENT_FILTER" = "all" ] && AGENT_FILTER=""

# ---------------------------------------------------------------------------
# Detect installed agents
# ---------------------------------------------------------------------------
HAS_CLAUDE=0
HAS_CODEX=0
HAS_HERMES=0

command -v claude  >/dev/null 2>&1 && HAS_CLAUDE=1
command -v codex   >/dev/null 2>&1 && HAS_CODEX=1
command -v hermes  >/dev/null 2>&1 && HAS_HERMES=1

# Apply --agent filter
if [ -n "$AGENT_FILTER" ]; then
  case "$AGENT_FILTER" in
    claude) HAS_CODEX=0; HAS_HERMES=0 ;;
    codex)  HAS_CLAUDE=0; HAS_HERMES=0 ;;
    hermes) HAS_CLAUDE=0; HAS_CODEX=0 ;;
    *) echo "Unknown agent: $AGENT_FILTER (use claude, codex, hermes, or all)"; exit 1 ;;
  esac
fi

if [ $HAS_CLAUDE -eq 0 ] && [ $HAS_CODEX -eq 0 ] && [ $HAS_HERMES -eq 0 ]; then
  echo "Error: no supported agent found on PATH."
  echo ""
  echo "Install one of:"
  echo "  Claude Code  — https://claude.ai/code"
  echo "  OpenAI Codex — https://developers.openai.com/codex"
  echo "  Hermes Agent — https://hermes-agent.nousresearch.com"
  exit 1
fi

# ---------------------------------------------------------------------------
# Map plugin-id → list of skill directory names inside agents/{codex,hermes}/
# ---------------------------------------------------------------------------
plugin_skills() {
  case "$1" in
    hn-submit)    echo "hn-submit" ;;
    threads-post) echo "threads-post threads-post-carousel threads-post-thread threads-post-spoiler" ;;
    "")           echo "hn-submit threads-post threads-post-carousel threads-post-thread threads-post-spoiler" ;;
    *)            echo "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Shared: clone or update the repo (needed for Codex and Hermes fallback)
# ---------------------------------------------------------------------------
ensure_clone() {
  if [ -d "$CLONE_DIR/.git" ]; then
    echo "Updating local clone at $CLONE_DIR..."
    git -C "$CLONE_DIR" pull --ff-only --quiet
  else
    echo "Cloning claude-socials to $CLONE_DIR..."
    git clone --quiet "$REPO_URL" "$CLONE_DIR"
  fi
}

# ---------------------------------------------------------------------------
# Claude Code install
# ---------------------------------------------------------------------------
install_claude() {
  echo ""
  echo "==> Claude Code"
  echo "Adding claude-socials marketplace..."
  claude plugin marketplace add "$MARKETPLACE"

  if [ -n "$PLUGIN_ID" ]; then
    if [ -n "$SCOPE" ]; then
      echo "Installing $PLUGIN_ID (scope: $SCOPE)..."
      claude plugin install "${PLUGIN_ID}@claude-socials" --scope "$SCOPE"
    else
      echo "Installing $PLUGIN_ID..."
      claude plugin install "${PLUGIN_ID}@claude-socials"
    fi
    echo "Done. Restart Claude Code to activate the plugin."
    echo "Usage: /$PLUGIN_ID"
  else
    echo "Marketplace added. Install a plugin with:"
    echo "  claude plugin install hn-submit@claude-socials"
    echo "  claude plugin install threads-post@claude-socials"
    echo ""
    echo "Available plugins:"
    echo "  hn-submit     — Submit to Hacker News"
    echo "  threads-post  — Post to Meta Threads (4 skills)"
  fi
}

# ---------------------------------------------------------------------------
# Codex install — symlink per-skill dirs into $HOME/.agents/skills/
# ---------------------------------------------------------------------------
install_codex() {
  echo ""
  echo "==> OpenAI Codex"
  ensure_clone

  CODEX_SKILLS_SRC="$CLONE_DIR/agents/codex/skills"
  CODEX_SKILLS_DST="$HOME/.agents/skills"
  mkdir -p "$CODEX_SKILLS_DST"

  SKILLS=$(plugin_skills "$PLUGIN_ID")
  for skill in $SKILLS; do
    src="$CODEX_SKILLS_SRC/$skill"
    dst="$CODEX_SKILLS_DST/$skill"
    if [ -d "$src" ]; then
      ln -sfn "$src" "$dst"
      echo "  Linked $skill → $dst"
    else
      echo "  Warning: skill '$skill' not found in $CODEX_SKILLS_SRC — skipping"
    fi
  done

  echo "Done. Codex will pick up skills from $CODEX_SKILLS_DST"
  echo "To update skills later: git -C $CLONE_DIR pull"
}

# ---------------------------------------------------------------------------
# Hermes install — try hermes skills tap, fall back to manual copy
# ---------------------------------------------------------------------------
install_hermes() {
  echo ""
  echo "==> Hermes Agent"

  # Try native hermes skills tap / install first
  if hermes skills tap add "$MARKETPLACE" >/dev/null 2>&1; then
    SKILLS=$(plugin_skills "$PLUGIN_ID")
    for skill in $SKILLS; do
      echo "  Installing $skill via hermes skills..."
      hermes skills install "$skill" || echo "  Warning: hermes skills install $skill failed — try manually"
    done
    echo "Done. Run 'hermes chat --toolsets skills' to verify."
    return
  fi

  # Fallback: clone + copy into Hermes skills directory
  echo "  'hermes skills tap' not available — falling back to manual copy..."
  ensure_clone

  HERMES_SRC="$CLONE_DIR/agents/hermes/skills/social-media"
  HERMES_DST="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}/social-media"
  mkdir -p "$HERMES_DST"

  SKILLS=$(plugin_skills "$PLUGIN_ID")
  for skill in $SKILLS; do
    src="$HERMES_SRC/$skill"
    dst="$HERMES_DST/$skill"
    if [ -d "$src" ]; then
      cp -r "$src" "$dst"
      echo "  Copied $skill → $dst"
    else
      echo "  Warning: skill '$skill' not found in $HERMES_SRC — skipping"
    fi
  done

  echo "Done. Skills copied to $HERMES_DST"
  echo "To update: re-run this script (it will re-copy from the updated clone)"
  echo "To verify: hermes chat --toolsets skills, then: skills_list()"
}

# ---------------------------------------------------------------------------
# Run installs for detected agents
# ---------------------------------------------------------------------------
[ $HAS_CLAUDE -eq 1 ] && install_claude
[ $HAS_CODEX  -eq 1 ] && install_codex
[ $HAS_HERMES -eq 1 ] && install_hermes

echo ""
echo "Installation complete."
