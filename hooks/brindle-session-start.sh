#!/usr/bin/env bash
# brindle-session-start.sh — SessionStart hook for Brindle
# Outputs a pre-rendered greeting card so the agent can paste it directly
# into message text without invoking the card renderer via Bash (which would
# produce collapsed `⎿ +N lines` chrome in the Claude Code UI).
#
# On any failure (pool missing, renderer crashed, picker unavailable) the
# hook falls back to the legacy "BRINDLE REACTION DUE — SESSION_START"
# trigger, so Brindle never goes dark at session start.

set -u

HERE="$(dirname "$0")"
source "$HERE/brindle-mute-check.sh"
if is_muted; then
  exit 0
fi

card=$(python3 "$HERE/brindle-pick-greeting.py" session_start 2>/dev/null) || {
  echo "BRINDLE REACTION DUE — SESSION_START"
  exit 0
}

# Discriminator line tells the agent (via SKILL.md) that the card below is
# pre-rendered and should be pasted directly — no Bash call needed.
echo "BRINDLE PRE-RENDERED CARD — SESSION_START"
echo "$card"
