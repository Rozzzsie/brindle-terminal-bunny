# Changelog

All notable changes to brindle-terminal-bunny are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] — Unreleased

First release. Ambient companion for Claude Code: session greetings, ship
celebrations, agent-authored error reactions, and on-demand `/buddy`
interactions.

### Added
- `hooks/brindle-card.py` — sparkle-bordered card renderer (reaction + stats
  modes) with dynamic border width and CJK/emoji-aware display-width math.
- `hooks/brindle-detect.sh` — PostToolUse:Bash hook that detects git commit
  and push success for ship celebrations.
- `hooks/brindle-reaction-render.py` — PostToolUse:Write hook that renders
  agent-authored cards from `/tmp/brindle-reaction.json` and injects them as
  pre-rendered payloads (eliminates the Bash auto-collapse double-render).
- `hooks/brindle-session-start.sh` and `hooks/brindle-session-end.sh` —
  SessionStart and Stop hooks that pre-render greeting cards from a pool.
- `hooks/brindle-pick-greeting.py` — greeting pool picker + card renderer
  wrapper used by the session hooks.
- `hooks/brindle-greetings.json` — editable bilingual greeting pool (8 + 8).
- `hooks/brindle-mute-check.sh` — shared mute check gated on the
  `BRINDLE_MUTED` environment variable.
- `hooks/hooks.json` — plugin hook manifest registering SessionStart, Stop,
  PostToolUse:Bash, and PostToolUse:Write entries.
- `.claude-plugin/plugin.json` — plugin manifest (MIT license).
- `skills/buddy/SKILL.md` — on-demand `/buddy` command skill, Brindle's
  personality rules, pose table, and literal-passthrough contract.
- `CLAUDE.md` — canonical agent contract for literal passthrough of
  `BRINDLE PRE-RENDERED CARD — SESSION_START / SESSION_END / REACTION`
  markers.
- `README.md` — product description, three-path install guide, configuration,
  architecture summary, FAQ.

### Fixed
- `skills/buddy/SKILL.md` — `buddy pet` art now explicitly instructs the agent
  to wrap the ASCII art in a code block. Backslashes outside code blocks are
  eaten by markdown rendering, causing a misaligned bullet + broken ears.

### Known gaps
- Phase 3 fresh-profile test pending: the canonical contract lives in both
  `CLAUDE.md` (plugin root) and `skills/buddy/SKILL.md` (the skill) — which
  layer actually carries passthrough reliability on a clean install is an
  empirical question, decided by a two-pass layer-isolation test before the
  first public release.
- Error detection is agent-side only (Claude Code's PostToolUse hooks do not
  fire on failed Bash calls). Error reactions may be inconsistent across
  Claude Code versions.
- Windows native (cmd / PowerShell) untested. WSL and Git Bash should work.
