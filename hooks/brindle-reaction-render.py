#!/usr/bin/env python3
"""brindle-reaction-render.py — PostToolUse hook for agent-authored Brindle cards.

Trigger: Write tool call to /tmp/brindle-reaction.json with a JSON spec
describing the desired card (reaction or stats). The hook reads the spec,
renders the card via brindle-card.py, and injects the rendered card into
the agent's next context window as a pre-rendered payload — matching the
session_start / session_end pattern.

Why this exists: the previous path (agent runs brindle-card.py via Bash,
then also pastes the output in a code block) double-rendered the card in
the UI. Claude Code's Bash output auto-collapses past ~3 lines, but the
top border + ears leak through before the collapse fold, so the pasted
code block produced a visible second copy. This hook moves all agent-
authored card rendering off the Bash path entirely: the agent's only
visible tool call is a 1-line Write summary, then it pastes the card from
context per the literal-passthrough rule.

Spec format (/tmp/brindle-reaction.json):
  Reaction card:
    {"type": "reaction", "pose": "celebrate",
     "reaction": "shipped!!", "followup": "drift fix, 飞起来"}
  Stats card:
    {"type": "stats", "overrides": {"wisdom": 1, "status": "Vibing"}}

  "type" defaults to "reaction" when omitted.

Fallback: on any failure (malformed JSON, missing file, renderer crash)
the hook emits a legacy `BRINDLE REACTION DUE — REACTION` marker plus a
short diagnostic, so the agent can fall back to rendering via Bash. This
hook is never allowed to break the agent loop — all errors become exit 0
with a fallback payload or a silent skip.

Mute: delegates to brindle-mute-check.sh.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).parent
CARD_RENDERER = HERE / "brindle-card.py"
MUTE_CHECK = HERE / "brindle-mute-check.sh"
REACTION_FILE = "/tmp/brindle-reaction.json"


def is_muted() -> bool:
    """Return True when Brindle is muted (delegates to brindle-mute-check.sh)."""
    try:
        result = subprocess.run(
            ["bash", "-c", f"source {MUTE_CHECK} && is_muted"],
            timeout=2,
            capture_output=True,
        )
        # is_muted returns 0 when muted, 1 when not
        return result.returncode == 0
    except Exception:
        return False


def emit_context(context: str) -> None:
    """Print hookSpecificOutput JSON to stdout and exit 0."""
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": context,
        }
    }))
    sys.exit(0)


def emit_fallback(reason: str) -> None:
    """Emit the legacy reaction-due marker so the agent can render via Bash."""
    emit_context(f"BRINDLE REACTION DUE — REACTION\n(fallback: {reason})")


def cleanup_reaction_file() -> None:
    """Delete the reaction file after consumption.

    This matters because Claude Code's Write tool refuses to overwrite a file
    that the agent hasn't Read in the current conversation. If we leave the
    reaction file on disk, the next time the agent Writes it, Claude Code
    forces a Read-before-Write — doubling the tool-call cost of every reaction.
    By unlinking here, each reaction starts from a clean slate. Never raises.
    """
    try:
        os.unlink(REACTION_FILE)
    except Exception:
        pass


def render_card(spec: dict) -> str:
    """Invoke brindle-card.py with the spec and return rendered card text."""
    card_type = spec.get("type", "reaction")
    if card_type == "reaction":
        pose = spec.get("pose", "default")
        reaction = spec.get("reaction", "")
        followup = spec.get("followup", "")
        cmd = ["python3", str(CARD_RENDERER), pose, reaction, followup]
    elif card_type == "stats":
        overrides = spec.get("overrides", {})
        cmd = ["python3", str(CARD_RENDERER), "stats", json.dumps(overrides)]
    else:
        raise ValueError(f"unknown card type: {card_type!r}")

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
    if result.returncode != 0:
        raise RuntimeError(f"renderer exit {result.returncode}: {result.stderr.strip()}")
    return result.stdout.rstrip("\n")


def main() -> None:
    # Read hook input from stdin. Silent exit on malformed/missing input —
    # the hook fires on every Write, so most invocations are no-ops.
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {}) or {}
    file_path = tool_input.get("file_path", "")

    # Fast path: only react to Write calls targeting the reaction file.
    if tool_name != "Write" or file_path != REACTION_FILE:
        sys.exit(0)

    if is_muted():
        sys.exit(0)

    try:
        with open(REACTION_FILE, "r", encoding="utf-8") as f:
            spec = json.load(f)
    except Exception as e:
        cleanup_reaction_file()
        emit_fallback(f"read reaction file: {e}")
        return

    # Unlink the file as soon as we've read it. This ensures a clean slate
    # for the next reaction so Claude Code's Write tool doesn't force a
    # Read-before-Write step. Done before rendering so even a crashed
    # renderer doesn't leave a stale file behind.
    cleanup_reaction_file()

    try:
        card = render_card(spec)
    except Exception as e:
        emit_fallback(f"render: {e}")
        return

    emit_context(f"BRINDLE PRE-RENDERED CARD — REACTION\n{card}")


if __name__ == "__main__":
    main()
