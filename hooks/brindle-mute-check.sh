#!/usr/bin/env bash
# brindle-mute-check.sh — shared mute check for all Brindle hooks
# Source this file, then call is_muted. Returns 0 if muted, 1 if not.

is_muted() {
  local claude_json="$HOME/.claude.json"
  if [ ! -f "$claude_json" ]; then
    return 1  # no file = not muted
  fi
  local muted
  muted=$(jq -r '.companionMuted // false' "$claude_json" 2>/dev/null)
  if [ "$muted" = "true" ]; then
    return 0  # muted
  fi
  return 1  # not muted
}
