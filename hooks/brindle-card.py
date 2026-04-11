#!/usr/bin/env python3
"""brindle-card.py — Render Brindle cards (sparkle-minimal design).

Usage:
  Reaction card:
    python3 hooks/brindle-card.py <pose> <reaction> <followup>

  Stat card:
    python3 hooks/brindle-card.py stats <json>
    where json = '{"debugging":78,"patience":99,"chaos":15,"wisdom":3,"snark":58,"status":"Vibing"}'

Output: sparkle-corner card with spaced-dash borders that stretch to fit content.
"""

import json
import random
import sys
import unicodedata
from datetime import date

POSES = {
    "surprise":   " ( o . o)",
    "sympathy":   " ( ; . ;)",
    "side-eye":   " ( > . >)",
    "encourage":  " ( ^ . ^)",
    "celebrate":  " ( ^ . ^) ♥",
    "default":    " ( • . •)",
}

EARS = "(\ __ /)"
BODY = " /> 🤍 <\\"

STATUSES = [
    "Survived the Purge",
    "Vibing",
    "Watching you code",
    "Ear wiggle mode",
    "Debugging with feelings",
    "0 bugs found (no look)",
    "Zen achieved",
    "Chewing context window",
]

STAT_RANGES = {
    "DEBUGGING": (60, 90),
    "PATIENCE":  (85, 99),
    "CHAOS":     (5, 30),
    "WISDOM":    (1, 8),
    "SNARK":     (40, 75),
}


def display_width(s: str) -> int:
    """Calculate the display width of a string in a terminal."""
    w = 0
    for ch in s:
        eaw = unicodedata.east_asian_width(ch)
        w += 2 if eaw in ("W", "F") else 1
    return w


MIN_DASHES = 18  # minimum border width — keeps short cards from feeling cramped


def make_border(lines: list[str]) -> str:
    """Build a sparkle border that fits the widest line."""
    max_w = max(display_width(l) for l in lines)
    n_dashes = max((max_w - 3) // 2 + 1, MIN_DASHES)
    return "✦" + " ─" * n_dashes + " ✦"


def render_stat_bar(value: int) -> str:
    """Render a 10-block stat bar with right-aligned number."""
    blocks = round(value / 10)
    bar = "█" * blocks + "░" * (10 - blocks)
    return f"{bar}   {value:>2}"


def render_reaction(pose_key: str, reaction: str, followup: str) -> str:
    face = POSES.get(pose_key, POSES["default"])

    lines = [
        f"  {EARS}",
        f" {face}  {reaction}",
        f" {BODY}  {followup}",
    ]

    border = make_border(lines)
    return "\n".join([border, "", *lines, "", border])


def render_stats(overrides: dict) -> str:
    # Generate stats — use overrides if provided, otherwise random
    stats = {}
    for name, (lo, hi) in STAT_RANGES.items():
        key = name.lower()
        stats[name] = overrides.get(key, random.randint(lo, hi))

    status = overrides.get("status", random.choice(STATUSES))

    # Build content lines
    lines = [
        f"  {EARS}",
        f" {POSES['default']}   BRINDLE",
        f" {BODY}   Rabbit · Original",
        "",
    ]

    for name, value in stats.items():
        bar = render_stat_bar(value)
        lines.append(f"  {name:<9}   {bar}")

    hatched = date(2026, 4, 5)
    age_days = (date.today() - hatched).days
    lines.append("")
    lines.append(f"  Nibbling around for {age_days} days")
    lines.append(f"  Status: {status}")

    border = make_border(lines)
    return "\n".join([border, *lines, border])


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: brindle-card.py <pose> <reaction> <followup>", file=sys.stderr)
        print("       brindle-card.py stats [json]", file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == "stats":
        overrides = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
        print(render_stats(overrides))
    else:
        if len(sys.argv) != 4:
            print("Usage: brindle-card.py <pose> <reaction> <followup>", file=sys.stderr)
            sys.exit(1)
        print(render_reaction(sys.argv[1], sys.argv[2], sys.argv[3]))
