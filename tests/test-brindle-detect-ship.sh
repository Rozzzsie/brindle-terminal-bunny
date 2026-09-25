#!/usr/bin/env bash
# test-brindle-detect-ship.sh — ship-detector tests.
#
# The Brindle ship detector used to key on OUTPUT TEXT alone: any stdout line
# shaped like "[word hex]" forged a SHIP marker, whatever the command was. It
# now keys on the COMMAND first (a git commit or push) and on the output second.
#
# Run from anywhere: bash tests/test-brindle-detect-ship.sh
# SUBJECT: this repo's hooks/brindle-detect.sh. Point BRINDLE_DETECT at another
# copy (an installed one, or an older version) to test that one instead.
# Needs bash and jq.

set -uo pipefail

DETECT="${BRINDLE_DETECT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/hooks/brindle-detect.sh}"
if [[ ! -f "$DETECT" ]]; then
  echo "ERROR: no detector at $DETECT — nothing verified."
  exit 1
fi

PASS=0; FAIL=0; RESULTS=()

# run_case <name> <want: fire|silent> <command> <stdout> <stderr> [expected summary substring]
run_case() {
  local name="$1" want="$2" cmd="$3" out="$4" err="$5" substr="${6:-}" payload got
  payload=$(jq -n --arg c "$cmd" --arg o "$out" --arg e "$err" \
    '{tool_name:"Bash", tool_input:{command:$c}, tool_response:{stdout:$o, stderr:$e}}')
  got=$(env -u BRINDLE_MUTED bash "$DETECT" <<<"$payload" 2>&1); local rc=$?
  if [[ $rc -ne 0 ]]; then
    RESULTS+=("FAIL  $name — detector exited rc=$rc: ${got:0:200}"); FAIL=$((FAIL+1)); return
  fi
  if [[ "$want" == "fire" ]]; then
    if ! grep -q "BRINDLE REACTION DUE — SHIP" <<<"$got"; then
      RESULTS+=("FAIL  $name — wanted a SHIP marker, got none"); FAIL=$((FAIL+1)); return
    fi
    if [[ -n "$substr" ]] && ! grep -qF "$substr" <<<"$got"; then
      RESULTS+=("FAIL  $name — SHIP marker lacks '$substr': ${got:0:200}"); FAIL=$((FAIL+1)); return
    fi
  else
    if [[ -n "$got" ]]; then
      RESULTS+=("FAIL  $name — wanted silence, got: ${got:0:200}"); FAIL=$((FAIL+1)); return
    fi
  fi
  RESULTS+=("PASS  $name"); PASS=$((PASS+1))
}

HEREDOC_COMMIT="git -C /tmp/repo commit --only -F - -- a.txt <<'EOF'
Subject line

Body
EOF"

# --- real ships still fire ---------------------------------------------------
run_case "C1: git commit summary fires, quoting the summary" fire \
  "git -C /tmp/repo commit -m 'x'" "[main 1a2b3c4d] x
 1 file changed, 1 insertion(+)" "" "[main 1a2b3c4d] x"
run_case "C2: root commit fires" fire \
  "git commit -m init" "[main (root-commit) 0f1e2d3] init" "" "(root-commit) 0f1e2d3"
run_case "C3: multi-line heredoc commit with -C fires" fire \
  "$HEREDOC_COMMIT" "gate chatter
[claude/master 9f3c2a1b7] Subject line" "" "9f3c2a1b7"
run_case "C4: push ref line on stderr fires" fire \
  "git push" "" "To github.com:o/r.git
   4e5f6a7b8..c9d0e1f2a  claude/master -> claude/master" "claude/master -> claude/master"
run_case "C5: push ref line on stdout (2>&1) fires" fire \
  "git -C /tmp/repo push 2>&1; echo rc=\$?" "To github.com:o/r.git
   4e5f6a7b8..c9d0e1f2a  claude/master -> claude/master
rc=0" "" "claude/master -> claude/master"

# --- forgeries stay silent (the original defect) ---------------------------------
run_case "F1: wrapper line [exited with code 0] from a non-git tool is silent" silent \
  "python3 scripts/review.py" "[exited with code 0]" ""
run_case "F2: column-aligned python count is silent" silent \
  "python3 -c 'print(counts)'" "[ok  3]
[warn 12]" ""
run_case "F3: a 7-hex bracket line from a non-git command is silent" silent \
  "cat notes.md" "[main 1a2b3c4] looks like a commit" ""
run_case "F4: an arrow on stderr from a non-git command is silent" silent \
  "python3 route.py" "" "  inbox -> main"
run_case "F5: a command that only MENTIONS git commit prints no commit summary, so is silent" silent \
  "grep -n 'git commit' notes.md" "[exited with code 0]" ""

# --- review round 1: verb before a separator, quoted git, hash bounds, branch anchor
run_case "C6: verb directly before ; still fires" fire \
  "git push; echo done" "" "   a1b2c3d..e4f5a6b  main -> main" "main -> main"
run_case "C7: verb directly before ) in a subshell still fires" fire \
  "(cd /tmp/repo && git push)" "" "   a1b2c3d..e4f5a6b  claude/master -> claude/master" "claude/master"
run_case "C8: git inside a quoted bash -c still fires" fire \
  "bash -c 'git commit -m x'" "[main 1a2b3c4] x" "" "1a2b3c4"
run_case "C9: a forced push still fires" fire \
  "git push --force-with-lease" "" " + 1a2b3c4...5d6e7f8 main -> main (forced update)" "main -> main"
run_case "C10: a 64-hex (SHA-256) commit still fires" fire \
  "git commit -m x" "[main $(printf 'a%.0s' {1..64})] x" "" "[main aaaa"
run_case "F8: a real git commit with a 6-hex bracket line is silent" silent \
  "git commit -m x" "[main 1a2b3c] x" ""
run_case "F9: a real git commit with a 65-hex bracket line is silent" silent \
  "git commit -m x" "[main $(printf 'a%.0s' {1..65})] x" ""
run_case "F10: a branch deletion is not a ship" silent \
  "git push origin --delete claude/wip" "" " - [deleted]         claude/wip"
run_case "F10b: a branch deletion printed with an arrow is not a ship" silent \
  "git push origin --delete claude/wip" "" " - [deleted]         (none) -> claude/wip"
run_case "F11: a branch merely prefixed main is not matched" silent \
  "git push" "" "   a1b2c3d..e4f5a6b  mainline -> mainline"
run_case "F6: a rejected push masked by echo is silent" silent \
  "git push 2>&1; echo done" " ! [rejected]        main -> main (fetch first)
done" ""
run_case "F7: git log output is not a commit" silent \
  "git log --oneline -3" "9f3c2a1b7 Fix the parser" ""

# --- review round 2: dry-run pushes, quoted verb, backtick substitution
PUSH_REF="   4e5f6a7b8..c9d0e1f2a  main -> main"
run_case "F12: git push --dry-run prints a real-looking ref line but is silent" silent \
  "git push --dry-run origin main" "" "To github.com:o/r.git
$PUSH_REF"
run_case "F13: git push -n inside a short-flag cluster is silent" silent \
  "git push -fn origin main" "" "$PUSH_REF"
run_case "F14: --dry-run after the refspec is silent" silent \
  "git -C /tmp/repo push origin main --dry-run" "" "$PUSH_REF"
run_case "C11: a push flag that merely starts with n (--no-verify) still fires" fire \
  "git push --no-verify origin main" "" "$PUSH_REF" "main -> main"
run_case "C12: a dry-run in a DIFFERENT git call does not mute a real push" fire \
  "git log -n 1; git push origin main" "" "$PUSH_REF" "main -> main"
run_case "C13: a quoted verb still fires" fire \
  "git \"commit\" -m x" "[main 1a2b3c4] x" "" "1a2b3c4"
run_case "C14: a push inside backtick substitution still fires" fire \
  "out=\`git push origin main\`" "" "$PUSH_REF" "main -> main"

# --- mute is honoured ----------------------------------------------------------
payload=$(jq -n '{tool_name:"Bash", tool_input:{command:"git commit -m x"}, tool_response:{stdout:"[main 1a2b3c4] x", stderr:""}}')
got=$(BRINDLE_MUTED=1 bash "$DETECT" <<<"$payload" 2>&1)
if [[ -z "$got" ]]; then RESULTS+=("PASS  M1: BRINDLE_MUTED silences a real commit"); PASS=$((PASS+1))
else RESULTS+=("FAIL  M1: BRINDLE_MUTED ignored: ${got:0:160}"); FAIL=$((FAIL+1)); fi

echo "brindle-detect ship tests — subject: $DETECT"
echo "----------------------------------------------"
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo "----------------------------------------------"
echo "Total: $((PASS + FAIL))   Pass: $PASS   Fail: $FAIL"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
