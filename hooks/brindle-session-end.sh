#!/usr/bin/env bash
# brindle-session-end.sh — Stop hook for Brindle
# Outputs Stop hook JSON: `{"decision":"approve","reason":"..."}`.
# NEVER use `decision: block` — that creates an infinite loop.
#
# The `reason` field embeds a pre-rendered farewell card (JSON-escaped) so
# the agent can paste it directly into message text without invoking the
# card renderer via Bash (which would produce collapsed `⎿ +N lines`
# chrome in the Claude Code UI).
#
# On any failure (pool missing, renderer crashed, picker unavailable) the
# hook falls back to the legacy reason string, so Brindle never goes dark
# at session end.

set -u

HERE="$(dirname "$0")"
source "$HERE/brindle-mute-check.sh"
if is_muted; then
  exit 0
fi

card=$(python3 "$HERE/brindle-pick-greeting.py" session_end 2>/dev/null) || {
  echo '{"decision":"approve","reason":"BRINDLE REACTION DUE — SESSION_END"}'
  exit 0
}

# Embed the rendered card in the reason field with correct JSON escaping.
# The discriminator line tells the agent (via SKILL.md) that the card is
# pre-rendered and should be pasted directly — no Bash call needed.
python3 - "$card" <<'PY'
import json, sys
card = sys.argv[1]
reason = "BRINDLE PRE-RENDERED CARD — SESSION_END\n" + card
print(json.dumps({"decision": "approve", "reason": reason}))
PY
