#!/usr/bin/env bash
# brindle-mute-check.sh — shared mute check for all Brindle hooks
# Source this file, then call is_muted. Returns 0 if muted, 1 if not.
#
# Mute mechanism: the BRINDLE_MUTED environment variable.
#   - Any non-empty value mutes Brindle for the current shell.
#   - For a persistent mute, drop `export BRINDLE_MUTED=1` in your shell rc
#     (~/.zshrc, ~/.bashrc, etc.).
#   - To unmute temporarily, `unset BRINDLE_MUTED` in the current shell.
#
# Why env var only: zero file I/O, zero race conditions, dead simple to
# explain in the README, and no stray state files to debug when something
# goes weird. She's a comfort bunny — the mute switch should be boring.

is_muted() {
  if [ -n "${BRINDLE_MUTED:-}" ]; then
    return 0  # muted
  fi
  return 1  # not muted
}
