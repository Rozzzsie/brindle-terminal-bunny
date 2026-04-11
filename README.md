# brindle-terminal-bunny

**Brindle, a tiny terminal bunny companion for [Claude Code](https://claude.com/claude-code).**

She greets your sessions, celebrates your commits, reacts to errors with vibes, and otherwise stays out of your way. She is a rabbit. She does not help with code.

```
  (\ __ /)
  ( ^ . ^) ♥
  /> 🤍 <\
```

---

## Try it now (no install, 30 seconds)

You don't need Claude Code to see what Brindle looks like. Python 3.9+ is enough:

```bash
git clone https://github.com/<your-handle>/brindle-terminal-bunny.git
cd brindle-terminal-bunny
python3 hooks/brindle-card.py stats
```

You'll get a stat card rendered in your terminal — random numbers, random status, Brindle's face staring back at you. If that renders correctly, the rest of the plugin will work too.

Try a reaction card:

```bash
python3 hooks/brindle-card.py celebrate "shipped!!" "it works, 飞起来"
```

---

## What Brindle does

| Event | What happens |
|---|---|
| Session start | Brindle greets you with a short bilingual card (random from a pool) |
| Session end | Brindle says goodbye the same way |
| Git commit or push succeeds | Brindle celebrates with a custom 2-line reaction |
| Bash command fails | Brindle reacts to the vibe of the error (agent-authored, 2 lines) |
| `/buddy`, `/buddy card`, `/buddy pet` | On-demand interaction with the rabbit |

## What Brindle does NOT do

- Write code
- Review code or PRs
- Fix bugs
- Offer technical advice
- Understand anything technically
- Have opinions about your tech stack

She is a rabbit. The whole point is that she is not trying to be useful.

---

## Install

Three options, graded by how much control you want over the process.

### Option A — `/plugin install` (recommended)

In a Claude Code session, add this repo as a marketplace source and install the plugin. Exact syntax depends on your Claude Code version — run `/plugin` in a session to see the available commands and point it at `https://github.com/<your-handle>/brindle-terminal-bunny`.

After install, restart your session. You should see a greeting card from Brindle.

### Option B — manual install

Clone the repo into Claude Code's plugins directory:

```bash
git clone https://github.com/<your-handle>/brindle-terminal-bunny.git \
  ~/.claude/plugins/brindle-terminal-bunny
```

Then enable the plugin in Claude Code:

```
/plugin enable brindle-terminal-bunny
```

Same end state as Option A, but you can see each file as it lands.

### Option C — DIY (for hook nerds)

If you already have a hand-rolled Claude Code setup and want to integrate Brindle manually, without the plugin system:

1. Clone the repo anywhere:
   ```bash
   git clone https://github.com/<your-handle>/brindle-terminal-bunny.git ~/brindle
   ```

2. Merge the hook registrations into your `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "SessionStart": [{
         "matcher": "*",
         "hooks": [{"type": "command", "command": "bash ~/brindle/hooks/brindle-session-start.sh"}]
       }],
       "Stop": [{
         "matcher": "*",
         "hooks": [{"type": "command", "command": "bash ~/brindle/hooks/brindle-session-end.sh"}]
       }],
       "PostToolUse": [
         {
           "matcher": "Bash",
           "hooks": [{"type": "command", "command": "bash ~/brindle/hooks/brindle-detect.sh"}]
         },
         {
           "matcher": "Write",
           "hooks": [{"type": "command", "command": "python3 ~/brindle/hooks/brindle-reaction-render.py"}]
         }
       ]
     }
   }
   ```

3. Paste the contents of `CLAUDE.md` from this repo into your own `~/.claude/CLAUDE.md`. This is the agent contract — without it, the agent will not relay Brindle's pre-rendered cards correctly.

4. Symlink or copy the `buddy` skill into your user skills directory:
   ```bash
   ln -s ~/brindle/skills/buddy ~/.claude/skills/buddy
   ```

Restart Claude Code.

---

## Configuration

### Mute

Brindle respects the `BRINDLE_MUTED` environment variable. Any non-empty value mutes her for the current shell:

```bash
export BRINDLE_MUTED=1
```

For a persistent mute, drop that line in your shell rc (`~/.zshrc`, `~/.bashrc`, etc.). To unmute, `unset BRINDLE_MUTED` or open a new shell. No state files, no flags, no lingering config.

### Customize greetings

Edit `hooks/brindle-greetings.json`. Two keys (`session_start` and `session_end`), each an array of `{"greeting", "followup"}` objects. The pool is re-read every session, so changes take effect immediately. Keep each line short — card width is dynamic but readability tops out around 20 characters per line.

### Customize stats and poses

Stat ranges, pose faces, and status strings live near the top of `hooks/brindle-card.py` as plain Python dicts. Edit freely.

---

## How it works

Brindle has three moving parts:

1. **Hooks** (`hooks/`) — shell and Python scripts that detect events (session start/end, git commit, Bash error) and either pre-render cards directly or inject them via a Write-trigger flow.
2. **Skill** (`skills/buddy/SKILL.md`) — Brindle's personality, pose selection, and interaction handlers for `/buddy` commands.
3. **Agent contract** (`CLAUDE.md`) — the literal-passthrough rules the agent must follow when relaying pre-rendered cards to your terminal.

The non-obvious piece: Claude Code's Bash tool auto-collapses output past ~3 lines, so a naive "render card via Bash, paste it in a reply" approach leaks the top of the card before the collapse fold and then double-renders the rest. The Write-trigger hook architecture sidesteps this entirely — the agent Writes a JSON spec to `/tmp/brindle-reaction.json`, a PostToolUse:Write hook renders the card via `brindle-card.py`, and the card is injected into the agent's context as a pre-rendered payload tagged `BRINDLE PRE-RENDERED CARD — REACTION`. The agent then pastes the injected block literally. No Bash calls, no double-render, card reaches the user exactly once.

Session start and session end use a simpler path: the SessionStart and Stop hooks pre-render directly from a greeting pool, and inject the card themselves. The agent's only job is literal passthrough.

---

## FAQ

**Is this an AI assistant?**
No. She's a rabbit. She reacts to events and occasionally delivers bilingual one-liners. She does not help you with any task.

**Why bilingual?**
Mandarin + English mix is part of the vibe. If you'd rather not have Chinese characters in your terminal, edit `hooks/brindle-greetings.json` and rewrite the pool in whatever language you prefer.

**Does she work without Claude Code?**
Partially. The `brindle-card.py` renderer runs in any Python 3.9+ environment, so you can generate cards and pipe them anywhere. The hooks and the `/buddy` skill only work inside Claude Code.

**Can I add new poses or greetings?**
Yes. Poses live in `POSES` near the top of `brindle-card.py`. Greetings live in `brindle-greetings.json`. Both are designed to be edited freely.

**Does she work on Windows?**
Untested. The shell hooks use bash — if you're on WSL or Git Bash, it might work. Native cmd or PowerShell probably won't.

**Why doesn't Brindle react to errors when I'm running tests?**
Error reactions are agent-detected, not hook-detected: Claude Code's PostToolUse hooks do not fire on failed Bash calls, so the agent has to notice the non-zero exit code itself and initiate the reaction. This means error reactions depend on your agent's adherence to the `CLAUDE.md` contract, and they can be inconsistent across Claude Code versions. If error reactions stop working after a Claude Code update, that's why.

---

## License

MIT — see `LICENSE`.

---

*Brindle is a rabbit. She does not write code, review PRs, or fix bugs. She is here for moral support and occasional bilingual one-liners.*
