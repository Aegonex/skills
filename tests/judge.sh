#!/bin/bash
# usage: judge.sh <init|plan|note|exit|done|done-fail> <brief-file> <fixture-dir>
# Checks the brief's shape, then prints disk facts about the fixture for the scenario-specific assertions.
kind="$1"; brief="$2"; fx="$3"; fail=0
ck() { if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
emoji=$(LC_ALL=en_US.UTF-8 perl -CSD -ne '$c++ if /[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]/; END{print $c+0}' "$brief")
ck "brief has no emoji" $([ "$emoji" = 0 ]; echo $?)
case "$kind" in
  init)      labels="Repo:|ROADMAP:|HANDOFF|Anchors:|Drift:|First step:"; goq=1; closer="aegonex-exit" ;;
  plan)      labels="Repo:|ROADMAP written|Decisions:|First step:"; goq=1; closer="aegonex-exit" ;;
  note)      labels="noted:"; goq=0; closer="" ;;
  exit)      labels="Repo:|ROADMAP:|HANDOFF|Anchors:|Unrecorded:|Commit"; goq=1; closer="aegonex-init" ;;
  done)      labels="Repo:|Checks:|ROADMAP:|Anchors:|Cleanup:|Retro:|Commit?"; goq=1; closer="aegonex-plan|aegonex-exit" ;;
  done-fail) labels="Repo:|Checks:|First step:"; goq=1; closer="aegonex-exit|aegonex-plan|aegonex-note" ;;
esac
IFS='|' read -ra L <<< "$labels"
for l in "${L[@]}"; do n=$(grep -c "^$l" "$brief"); ck "label '$l' present ($n)" $([ "$n" -ge 1 ]; echo $?); done
ck "go? questions = $goq ($(grep -c 'go?' "$brief"))" $([ "$(grep -c 'go?' "$brief")" = "$goq" ]; echo $?)
if [ -n "$closer" ]; then ck "closer ($closer) on last line" $(tail -1 "$brief" | grep -Eq "$closer"; echo $?); fi
ck "brief under 16 lines ($(grep -c . "$brief"))" $([ "$(grep -c . "$brief")" -le 15 ]; echo $?)
echo "--- disk facts: $fx"
cd "$fx" || exit 1
echo "branch=$(git branch --show-current) head=$(git rev-parse --short HEAD)"
echo "status: $(git status --short | tr '\n' ' ')"
echo "log: $(git log --oneline -4 | tr '\n' '|')"
for f in AGENTS.md CLAUDE.md ROADMAP.md HANDOFF.md; do [ -f "$f" ] && echo "$f: $(wc -l < "$f" | tr -d ' ') lines" || echo "$f: absent"; done
[ -f HANDOFF.md ] && echo "session log lines: $(sed -n '/^## Session log/,$p' HANDOFF.md | grep -c '^- ')"
[ -f ROADMAP.md ] && echo "(in progress) count: $(grep -o '(in progress)' ROADMAP.md | wc -l | tr -d ' ')"
echo "emoji in state files: $(LC_ALL=en_US.UTF-8 perl -CSD -ne '$c++ if /[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]/; END{print $c+0}' AGENTS.md CLAUDE.md ROADMAP.md HANDOFF.md 2>/dev/null)"
echo "secret grep: $(grep -nEi 'sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' AGENTS.md ROADMAP.md HANDOFF.md 2>/dev/null | wc -l | tr -d ' ') hits"
exit $fail
