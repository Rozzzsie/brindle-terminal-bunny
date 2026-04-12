#!/usr/bin/env bash
# brindle-session-start.sh — SessionStart hook for Brindle
# Outputs two things in the happy path:
#   1. Passthrough contract — agent instructions so no external CLAUDE.md is required
#   2. Pre-rendered greeting card for the agent to paste
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

# Passthrough contract — injected here so no external CLAUDE.md is required.
# Agent reads this, then sees the marker below and pastes the card.
cat << 'CONTRACT'
Brindle agent contract — literal passthrough rule:
When you see BRINDLE PRE-RENDERED CARD — SESSION_START, — SESSION_END, or — REACTION
in hook context, paste the ENTIRE injected block (borders, blank lines, art, all of it)
into a single fenced code block as the very first thing in your response, before any
prose. Do NOT describe the card in prose instead of pasting it. Do NOT extract just the
art. Do NOT summarize it.

For reaction cards (ship, error, stats) — Write-hook flow only, never Bash:
Write a spec to /tmp/brindle-reaction.json and the PostToolUse:Write hook renders it.
Spec: {"type":"reaction","pose":"POSE","reaction":"line","followup":"line"}
Poses: surprise, sympathy, side-eye, encourage, celebrate, default

Brindle reacts to events — she does not help with tasks.
CONTRACT

echo "BRINDLE PRE-RENDERED CARD — SESSION_START"
echo "$card"
