#!/usr/bin/env bash
# brindle-detect.sh — PostToolUse:Bash hook for Brindle
# Detects ships (git commit/push success) only.
# Error detection is agent-side — PostToolUse hooks don't fire on Bash failures.
#
# Keys on the COMMAND first, then the output. Output text alone is forgeable:
# any tool printing a "[word hex]" line, or an arrow on stderr, would raise a
# SHIP marker with no git command run. Tests: tests/test-brindle-detect-ship.sh.

set -euo pipefail

# Source mute check
source "$(dirname "$0")/brindle-mute-check.sh"
if is_muted; then
  exit 0
fi

# Read hook input from stdin
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
STDOUT=$(echo "$INPUT" | jq -r '.tool_response.stdout // ""')
STDERR=$(echo "$INPUT" | jq -r '.tool_response.stderr // ""')
# Both streams: a push run as `git push 2>&1` puts its ref line on stdout.
OUTPUT="$STDOUT
$STDERR"

# runs_git <verb>: the command invokes git with <verb> as a word, options such
# as `-C <path>` allowed in between, never across a ; & | separator. The verb
# may sit directly before a separator, `)` or a quote (`git push; …`,
# `(… && git push)`, `bash -c 'git commit …'`), may itself be quoted
# (`git "commit"`), and the call may sit inside backtick substitution.
# Known limits:
#  - the match is quote-blind. A quoted `;` counts as a separator, and a command
#    that merely QUOTES "git commit" matches here; the output gate below (a real
#    summary or ref line) is what keeps those silent.
#  - the output gate reads the whole command's output, so an OLD ref line
#    printed earlier in the same command (`cat last-push.log; git push`) fires.
#  - `git push --porcelain` prints no ` -> ` and is never detected.
runs_git() {
  local re="(^|[[:space:];&|(/'\"\`])git[[:space:]]([^;&|]*[[:space:]])?['\"]?$1([[:space:];&|)'\"\`]|\$)"
  # A here-string, not a pipe: under pipefail, grep -q exiting early on a long
  # command would SIGPIPE the writer and read as "no git".
  grep -qE "$re" <<<"$CMD"
}

# --- Ship detection ---
# Git commit: "[branch hash] message", hash 7 hex up to 64 (a full SHA-256
# object name). The floor of 7 is deliberate: it is git's default abbreviation.
# A repo configured with core.abbrev below 7 goes undetected, which is
# preferred over loosening the shape a forged line has to match.
if runs_git commit; then
  COMMIT_SUMMARY=$(printf '%s\n' "$OUTPUT" | grep -E '^\[[^]]+ [0-9a-f]{7,64}\]' | head -1 || true)
  if [[ -n "$COMMIT_SUMMARY" ]]; then
    jq -n \
      --arg ctx "BRINDLE REACTION DUE — SHIP: $COMMIT_SUMMARY" \
      '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
    exit 0
  fi
fi

# A dry run (`--dry-run`, or `-n` alone or in a short-flag cluster such as `-fn`)
# prints ref lines identical to a real push, so the command is the only tell.
# The flag must sit inside the same push invocation, never past a separator.
push_is_dry_run() {
  local re="push[[:space:]]([^;&|]*[[:space:]])?(--dry-run|-[a-zA-Z]*n[a-zA-Z]*)([[:space:];&|)'\"\`]|\$)"
  grep -qE "$re" <<<"$CMD"
}

# Git push: a ref-update line such as "a1..b2  main -> main", never a rejected
# (`!`) or deleted (`-`) one. Only main, master and claude/* count as ships;
# the branch name is anchored so `mainline` is not main.
if runs_git push && ! push_is_dry_run; then
  PUSH_SUMMARY=$(printf '%s\n' "$OUTPUT" \
    | grep -E '[[:space:]]->[[:space:]]+(main|master|claude/[^[:space:]]*)([[:space:]]|$)' \
    | grep -vE '^[[:space:]]*[!-]|\[rejected\]|\[deleted\]' | head -1 | sed 's/^[[:space:]]*//' || true)
  if [[ -n "$PUSH_SUMMARY" ]]; then
    jq -n \
      --arg ctx "BRINDLE REACTION DUE — SHIP: pushed $PUSH_SUMMARY" \
      '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
    exit 0
  fi
fi

# Nothing detected — exit silently
exit 0
