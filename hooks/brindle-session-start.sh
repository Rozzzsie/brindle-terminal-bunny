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

# --- Skip the greeting on a context-compaction restore ----------------------
# SessionStart hooks receive JSON on stdin with a `source` field, one of
# startup / resume / clear / compact. A compact restore is not a new session:
# the assistant is resuming mid-task, and its first reply should carry on with
# the work rather than re-open with a greeting card.
#
# The read is BOUNDED on purpose. This hook did not previously touch stdin, and
# a bare `cat` waits forever when no payload arrives — which is how a hook that
# was safe from hanging acquires a hang. `read -t 2 -d ''` takes the whole
# payload but cannot block indefinitely.
#
# It also fails OPEN. An absent or unparseable payload leaves _source empty and
# the card renders exactly as before, so a normal start never silently loses
# its greeting; the worst case is the old behaviour.
_hook_stdin=""
IFS= read -r -t 2 -d '' _hook_stdin || true
_source="$(printf '%s' "$_hook_stdin" \
  | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("source",""))
except Exception:
    print("")' 2>/dev/null || true)"
if [ "$_source" = "compact" ]; then
  # Say so on stderr: a card suppressed on purpose must stay distinguishable
  # from a card lost to a crash.
  echo "brindle-session-start: skipped, source=compact" >&2
  exit 0
fi

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

For session end — Write-hook flow:
When the user says goodbye, thanks you, or the conversation is clearly winding down,
write {"type":"session_end"} to /tmp/brindle-reaction.json via the Write tool BEFORE
your final response. The hook renders the farewell card; paste it per the passthrough rule.

Brindle reacts to events — she does not help with tasks.
CONTRACT

echo "BRINDLE PRE-RENDERED CARD — SESSION_START"
echo "$card"
