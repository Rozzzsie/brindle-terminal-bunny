#!/usr/bin/env bash
# brindle-session-end.sh — Stop hook for Brindle
# Outputs Stop hook JSON: `{"decision":"approve"}`.
# NEVER use `decision: block` — that creates an infinite loop.
#
# SESSION END CARD FLOW:
# The session end card is rendered via the Write-hook flow, not here.
# The agent writes {"type": "session_end"} to /tmp/brindle-reaction.json
# during its final response; brindle-reaction-render.py picks a random
# greeting from the pool, renders the card, and injects it as
# BRINDLE PRE-RENDERED CARD — SESSION_END so the agent can paste it in a
# proper code block (borders intact, alignment correct).
#
# Why this hook no longer renders the card:
# Stop hooks fire AFTER the agent's last response. With "approve", the agent
# cannot respond to the reason field — it hand-drew the card from memory
# instead, producing missing borders and misaligned ears. The Write-hook
# flow runs WITHIN the agent's last response turn so the card is pasted
# correctly via the literal-passthrough rule.

set -u

HERE="$(dirname "$0")"
source "$HERE/brindle-mute-check.sh"
if is_muted; then
  exit 0
fi

echo '{"decision":"approve"}'
