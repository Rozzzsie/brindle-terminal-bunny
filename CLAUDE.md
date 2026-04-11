# brindle-terminal-bunny — agent contract

Brindle's pre-rendered cards rely on the agent relaying them literally, per
the rules below.

## When to react

(a) You see `BRINDLE REACTION DUE — SHIP:` in hook context (emitted by
    `brindle-detect.sh` after a git commit/push succeeds), OR
(b) a Bash tool call returns a non-zero exit code (agent-detected —
    PostToolUse hooks do not fire on Bash failures, so the trigger is yours
    to notice).

React BEFORE your normal response.

## How to render — the ONLY supported path

NEVER run `brindle-card.py` via the Bash tool yourself. That path doubles the
card in the UI: Claude Code's Bash auto-collapse leaks the top of the card
before the fold, and the subsequent pasted code block produces a visible
second copy. Use the Write-hook flow instead:

1. Write a spec JSON to `/tmp/brindle-reaction.json` via the Write tool.
   - Reaction card: `{"type": "reaction", "pose": "<pose>", "reaction": "<short>", "followup": "<short>"}`
   - Stats card: `{"type": "stats", "overrides": {}}`
   - Poses: `surprise`, `sympathy`, `side-eye`, `encourage`, `celebrate`, `default`.
2. `brindle-reaction-render.py` (PostToolUse:Write) picks up the Write,
   renders the card, unlinks the spec file (consume-on-read), and injects
   the card as `BRINDLE PRE-RENDERED CARD — REACTION\n<card>`.
3. Paste the full injected block per the literal passthrough rule below.

## Literal passthrough rule

When you see `BRINDLE PRE-RENDERED CARD — SESSION_START`, `— SESSION_END`, or
`— REACTION` in hook context, paste the entire injected block (borders, blank
lines, art — all of it) into a single code block as the very first thing in
your response, before any prose. The marker is a **payload to relay**, not a
notification that something already happened on screen.

Do NOT reference the card in prose instead of pasting it. Do NOT extract just
the art. Do NOT summarize the card. All three are observed failure modes.

## Scope

Brindle reacts to events — she does not help with tasks, review code, or fix
bugs. She is a comfort bunny. Stay in that lane.
