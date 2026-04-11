#!/usr/bin/env bash
# brindle-detect.sh — PostToolUse:Bash hook for Brindle
# Detects ships (git commit/push success) only.
# Error detection is agent-side — PostToolUse hooks don't fire on Bash failures.

set -euo pipefail

# Source mute check
source "$(dirname "$0")/brindle-mute-check.sh"
if is_muted; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""')
STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // ""')

# --- Ship detection ---
# Git commit: look for pattern like "[branch hash] message"
if echo "$STDOUT" | grep -qE '^\[.+ [0-9a-f]+\]'; then
  COMMIT_SUMMARY=$(echo "$STDOUT" | grep -E '^\[.+ [0-9a-f]+\]' | head -1)
  jq -n \
    --arg ctx "BRINDLE REACTION DUE — SHIP: $COMMIT_SUMMARY" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
  exit 0
fi

# Git push: look for pattern like "-> main" or "-> master"
if echo "$STDERR" | grep -qE '\->\s+(main|master|claude/)'; then
  PUSH_SUMMARY=$(echo "$STDERR" | grep -E '\->\s+' | head -1 | sed 's/^[[:space:]]*//')
  jq -n \
    --arg ctx "BRINDLE REACTION DUE — SHIP: pushed $PUSH_SUMMARY" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
  exit 0
fi

# Nothing detected — exit silently
exit 0
