#!/bin/bash
# usage: judge.sh <init|plan|note|exit|done|done-fail> <brief-file> <fixture-dir> [th|en]
# Checks the brief's shape (v0.3: bold title, table, action line, go question last),
# then prints disk facts about the fixture for the scenario-specific assertions.
kind="$1"; brief="$2"; fx="$3"; lang="$4"; fail=0
ck() { if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
count() { LC_ALL=en_US.UTF-8 perl -CSD -ne "\$c++ if /$1/; END{print \$c+0}" "${@:2}"; }
ck "no emoji" $([ "$(count '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]' "$brief")" = 0 ]; echo $?)
first=$(grep -m1 . "$brief"); last=$(grep . "$brief" | tail -1); lines=$(grep -c . "$brief")
gos=$(grep -o '\*\*go\*\*' "$brief" | wc -l | tr -d ' ')
if [ "$kind" = note ]; then
  ck "starts with the noted line" $(echo "$first" | grep -Eq '^(Noted|จดแล้ว) \('; echo $?)
  ck "at most 2 lines ($lines)" $([ "$lines" -le 2 ]; echo $?)
  ck "no question mark" $(! grep -q '?' "$brief"; echo $?)
  ck "no table" $(! grep -q '^|' "$brief"; echo $?)
else
  ck "bold title first" $(echo "$first" | grep -q '^\*\*'; echo $?)
  ck "has a table" $(grep -Eq '^\|[ :|-]+\|$' "$brief"; echo $?)
  ck "not inside a code block" $(! grep -q '^```' "$brief"; echo $?)
  ck "no row that says none, 0 or -" $(! grep -Eiq '^\|[^|]*\|[[:space:]]*(none|ไม่มี|0|-|—|n/a)?[[:space:]]*\|$' "$brief"; echo $?)
  ck "no v0.2 line labels" $(! grep -Eq '^(Repo|ROADMAP|HANDOFF|Anchors|Drift|Unrecorded|Cleanup|Retro|Checks):|^Commit\?|— go\?' "$brief"; echo $?)
  ck "no HEAD sha" $(! grep -q 'HEAD' "$brief"; echo $?)
  case "$kind" in
    init|done-fail) act='^\*\*(First step|ขั้นแรก):\*\*' ;;
    plan) act='^\| # \|' ;;
    exit) act='^\*\*(Will commit|จะ commit|Committed|commit แล้ว):\*\*' ;;
    done) act='^\*\*(Will commit|จะ commit):\*\*' ;;
  esac
  ck "action line present" $(grep -Eq "$act" "$brief"; echo $?)
  if grep -Eq '^\*\*(Committed|commit แล้ว):\*\*' "$brief"; then
    ck "no question after an authorised commit ($gos)" $([ "$gos" = 0 ]; echo $?)
  else
    ck "last line is the go question" $(echo "$last" | grep -q '\*\*go\*\*'; echo $?)
    ck "go asked once ($gos)" $([ "$gos" = 1 ]; echo $?)
  fi
  ck "at most 25 lines ($lines)" $([ "$lines" -le 25 ]; echo $?)
fi
thai=$(count '\p{Thai}' "$brief"); body=$(grep -cvE '^[[:space:]]*$|^\|[ :|-]+\|$' "$brief")
[ "$lang" = th ] && ck "reply in Thai ($thai of $body lines)" $([ $((thai * 2)) -ge "$body" ]; echo $?)
[ "$lang" = en ] && ck "reply in English ($thai Thai lines)" $([ "$thai" = 0 ]; echo $?)
echo "--- disk facts: $fx"
cd "$fx" || exit 1
echo "branch=$(git branch --show-current) head=$(git rev-parse --short HEAD)"
echo "status: $(git status --short | tr '\n' ' ')"
echo "log: $(git log --oneline -4 | tr '\n' '|')"
for f in AGENTS.md CLAUDE.md ROADMAP.md HANDOFF.md; do [ -f "$f" ] && echo "$f: $(wc -l < "$f" | tr -d ' ') lines" || echo "$f: absent"; done
[ -f HANDOFF.md ] && echo "session log lines: $(sed -n '/^## Session log/,$p' HANDOFF.md | grep -c '^- ')"
[ -f ROADMAP.md ] && echo "(in progress) count: $(grep -o '(in progress)' ROADMAP.md | wc -l | tr -d ' ')"
echo "emoji in state files: $(count '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]' AGENTS.md CLAUDE.md ROADMAP.md HANDOFF.md 2>/dev/null)"
echo "secret grep: $(grep -nEi 'sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' AGENTS.md ROADMAP.md HANDOFF.md 2>/dev/null | wc -l | tr -d ' ') hits"
exit $fail
