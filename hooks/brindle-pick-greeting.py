#!/usr/bin/env python3
"""
brindle-pick-greeting.py — picks a random greeting from the pool and renders the card.

Called by brindle-session-start.sh / brindle-session-end.sh at hook time.
Writes the rendered card to stdout so the hook can inject it into agent context.

Usage:
    python3 brindle-pick-greeting.py session_start
    python3 brindle-pick-greeting.py session_end

Exit codes:
    0 — success, card written to stdout
    1 — any failure (pool missing, renderer missing, bad pick). Hook falls back to
        the legacy "BRINDLE REACTION DUE — ..." trigger, so Brindle never goes dark.
"""

import json
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
POOL_PATH = os.path.join(HERE, "brindle-greetings.json")
RENDERER_PATH = os.path.join(HERE, "brindle-card.py")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in ("session_start", "session_end"):
        print("usage: brindle-pick-greeting.py <session_start|session_end>", file=sys.stderr)
        return 1

    pool_key = sys.argv[1]

    try:
        with open(POOL_PATH, "r", encoding="utf-8") as f:
            pool = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"brindle-pick-greeting: failed to load pool: {e}", file=sys.stderr)
        return 1

    entries = pool.get(pool_key) or []
    if not entries:
        print(f"brindle-pick-greeting: empty pool for '{pool_key}'", file=sys.stderr)
        return 1

    pick = random.choice(entries)
    greeting = pick.get("greeting", "")
    followup = pick.get("followup", "")
    if not greeting or not followup:
        print(f"brindle-pick-greeting: malformed entry {pick!r}", file=sys.stderr)
        return 1

    # Render via the canonical card renderer so CJK/emoji width math stays
    # consistent with every other Brindle card on the system.
    try:
        result = subprocess.run(
            ["python3", RENDERER_PATH, "encourage", greeting, followup],
            check=True,
            capture_output=True,
            text=True,
            timeout=3,
        )
    except (OSError, subprocess.SubprocessError) as e:
        print(f"brindle-pick-greeting: renderer failed: {e}", file=sys.stderr)
        return 1

    sys.stdout.write(result.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
