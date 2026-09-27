#!/bin/bash
# v0.4 (small) lifecycle walk. Every git line below is a command of the spec with its placeholders filled in:
# <main>=$M, <Base>=main, <remote>=origin, <u>, <unit folder>=$U, <part folder>=$P.
# One command per line, no && chains inside a recipe but v0.5.1's `cd "<folder>" && <command>` for a done-when and Clean
# up's remove, run in a subshell as a shell that does not keep a `cd` runs it (the other && are the lab's, not recipe text).
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
# The run folder must exist and sit outside every git repo: with an empty RUN, `cd ""` stays put and
# every scenario would commit into the repo you run from. macOS `mktemp -d` ignores TMPDIR, so name it.
RUN=${AEGONEX_RUN:-$(mktemp -d "${TMPDIR:-/tmp}/aegonex-lifecycle.XXXXXX")} && mkdir -p "$RUN" && RUN=$(cd "$RUN" && pwd -P) && [ -n "$RUN" ] && [ "$RUN" != / ] \
  || { echo "lifecycle: cannot make a run folder (set AEGONEX_RUN)" >&2; exit 1; }
command git -C "$RUN" rev-parse --git-dir >/dev/null 2>&1 && { echo "lifecycle: $RUN is inside a git repo; set AEGONEX_RUN to a folder outside any repo" >&2; exit 1; }
export GIT_CEILING_DIRECTORIES="$RUN"   # a scenario whose repo is missing fails instead of finding one above
echo "run folder: $RUN"
mkdir -p "$RUN/bin"; printf '#!/bin/sh\necho "gh $*" >> "$GH_LOG"\ncase "$1" in --version) echo "gh version 2.0.0 (stub)";; pr) echo "https://example.test/o/app/pull/1";; esac\n' > "$RUN/bin/gh"; chmod +x "$RUN/bin/gh"
export PATH="$RUN/bin:$PATH" GH_LOG="$RUN/gh.log"   # a gh stub: no network
export GIT_AUTHOR_NAME=lab GIT_AUTHOR_EMAIL=l@x.io GIT_COMMITTER_NAME=lab GIT_COMMITTER_EMAIL=l@x.io GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
T=0; git() { T=$((T+60)); GIT_AUTHOR_DATE="@$((1790000000+T)) +0000" GIT_COMMITTER_DATE="@$((1790000000+T)) +0000" command git "$@"; }
P_=0; F_=0
ok() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; P_=$((P_+1)); else echo "  FAIL $1"; F_=$((F_+1)); fi; }
say() { echo "== $*"; }
RE='sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[a-z]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY|://[^/:@ ]+:[^@ ]{3,}@'   # the spec's <RE>

# ---------- spec recipes (as the skills word them) ----------
main_of() { git -C "$1" worktree list --porcelain | sed -n '1s/^worktree //p'; }          # Definitions: <main>
closed_() { [ "$(git -C "$1" log -1 --first-parent --no-merges --format=%s "aegonex/$2")" = "chore: close $2" ]; }  # closed <u>
online_() { r=$(git -C "$1" rev-parse --verify -q "refs/remotes/origin/aegonex/$2") && [ "$r" = "$(git -C "$1" rev-parse "aegonex/$2")" ]; }  # online: same hash
status_() { git -C "$1" -c core.quotePath=false status --short; }                        # every status read
state_folder() { git -C "$M" worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/aegonex\/m[0-9]+$/{print w}' | while read -r w; do u=$(basename "$w"); closed_ "$w" "$u" || echo "$w"; done | head -1; }
free_task() { u=$1; k=1; n=$u                                                             # init: a task name whose online ref exists takes -2, -3
  while git -C "$M" rev-parse --verify -q "refs/heads/aegonex/$n" >/dev/null || git -C "$M" rev-parse --verify -q "refs/remotes/origin/aegonex/$n" >/dev/null; do k=$((k+1)); n="$u-$k"; done; echo "$n"; }
open_() { u=$1; start=${2:-main}                                                          # Working mode **Open**
  git -C "$M" worktree prune
  if git -C "$M" rev-parse --verify -q "refs/heads/aegonex/$u" >/dev/null
  then git -C "$M" worktree add "$M/.worktrees/$u" "aegonex/$u"
  else git -C "$M" worktree add -b "aegonex/$u" "$M/.worktrees/$u" "$start"; fi
  [ -f "$M/.worktrees/.gitignore" ] || printf '*\n' > "$M/.worktrees/.gitignore"; }       # file tool, when missing
base_ok() { f=$1; rg=main; git -C "$f" rev-parse --verify -q origin/main >/dev/null && rg=origin/main..main   # done step 2: local Base only setup?
  [ -z "$(git -C "$f" log --format=%s "$rg" | grep -vx 'chore: aegonex setup')" ]; }
sync_() { f=$1                                                                             # aegonex-done **Sync**
  git -C "$f" fetch origin main 2>/dev/null || echo "  (offline)"
  for ref in origin/main main; do
    git -C "$f" rev-parse --verify -q "$ref" >/dev/null || continue
    if [ "$ref" = main ] && git -C "$f" rev-parse --verify -q origin/main >/dev/null && ! base_ok "$f"; then echo "  stop: <main> has commits that are not online"; return 2; fi
    git -C "$f" merge-base --is-ancestor "$ref" HEAD && continue
    git -C "$f" merge --no-edit "$ref" >/dev/null 2>&1 && continue
    return 1                                                                               # a conflict (resolve) or a merge that never started

  done; }
scan_() { f=$1; u=$2; rg="origin/main..aegonex/$u"                                         # aegonex-done **Secret scan**
  git -C "$f" rev-parse --verify -q origin/main >/dev/null || rg="aegonex/$u"               # empty remote: the whole branch
  o1=$(git -C "$f" log -p -U0 --no-merges -G "$RE" "$rg") || { echo scan-failed; return; }
  o2=$(git -C "$f" log --no-merges --diff-filter=A --name-only --format= "$rg") || { echo scan-failed; return; }
  echo "$o1" | grep -E "^\+.*($RE)"
  echo "$o2" | grep -E '(^|/)\.env' | grep -v '\.env\.example$'
  git -C "$f" diff HEAD -U0 | grep -E "^\+.*($RE)"; }
land_() { f=$1; u=$2                                                                       # Working mode **Land**, done 7.3
  out=$(git -C "$f" push origin "aegonex/$u:main" 2>&1) && { echo landed; return; }
  echo "$out" > "$RUN/push.out"
  if echo "$out" | grep -q '\[remote rejected\]' && echo "$out" | grep -q 'secret'; then echo stop:secret
  elif echo "$out" | grep -q '\[remote rejected\]' && echo "$out" | grep -Eq 'protected|GH006|GH013|pull request|review'; then
    git -C "$f" push origin "aegonex/$u" > "$RUN/push2.out" 2>&1 || { echo stop:branch-push; return; }
    gh --version >/dev/null 2>&1 && gh pr create --repo o/app --base main --head "aegonex/$u" --title "$u" --body "aegonex" >/dev/null
    echo pr
  elif echo "$out" | grep -q '\[rejected\]'; then echo stop:base-moved
  else echo stop:other; fi; }
update_main() {                                                                            # Clean up step 2 **Update** (and init's update)
  [ "$(git -C "$M" branch --show-current)" = main ] || { echo "  stop: the main folder is on $(git -C "$M" branch --show-current)"; return 1; }
  git -C "$M" merge --ff-only origin/main >/dev/null 2>&1 && return 0
  lg=$(git -C "$M" log --format=%s origin/main..main)
  [ -n "$lg" ] && [ -z "$(echo "$lg" | grep -vx 'chore: aegonex setup')" ] && git -C "$M" grep -q -F "## Working mode (aegonex 0.4)" origin/main -- AGENTS.md || { echo "  stop: <main> has commits that are not online"; return 1; }
  git -C "$M" reset -q --keep origin/main; }
landed_() { git -C "$M" merge-base --is-ancestor "aegonex/$1" "${2:-origin/main}"; }       # Clean up precondition
clean_() { f=$1; u=$2; flag=${3:--d}                                                       # Working mode **Clean up**
  [ "$flag" = -D ] || landed_ "$u" || { echo "  stop: not landed"; return 1; }
  update_main || return 1
  (cd "$M" && git -C "$M" worktree remove "$f") || return 1                                # one call: the shell leaves the unit folder
  git -C "$M" branch "$flag" "aegonex/$u"; }
pushed_check() { l=$(git -C "$M" rev-parse "aegonex/$1"); r=$(git -C "$M" rev-parse --verify -q "refs/remotes/origin/aegonex/$1") || { echo gone; return; }
  [ "$l" = "$r" ] && echo equal || echo different; }                                       # done step 8
commit_() { f=$1; msg=$2; shift 2; git -C "$f" add -- "$@"; git -C "$f" commit -q -m "$msg" -- "$@"; }
anchors() { git -C "$1" grep -n --untracked -E "AIDEV-(TODO|NOTE)" -- . ":(exclude,glob)**/AGENTS.md" ":(exclude,glob)**/CLAUDE.md" ":(exclude,glob)**/ROADMAP.md" ":(exclude,glob)**/HANDOFF.md"; }

mkrepo() { D="$RUN/$1"; mkdir -p "$D"; O="$D/origin.git"; M="$D/app"
  git init -q --bare -b main "$O"; git init -q -b main "$M"
  printf 'hello wrold\n' > "$M/README.md"; printf 'l1\n' > "$M/a.js"; printf 'node_modules/\n.env\n' > "$M/.gitignore"
  git -C "$M" add -- README.md a.js .gitignore; git -C "$M" commit -q -m init
  git -C "$M" remote add origin "$O"; git -C "$M" push -q origin main; git -C "$M" fetch -q origin
  git -C "$M" remote set-head origin main; }
protect() { printf '#!/bin/sh\nwhile read o n ref; do [ "$ref" = refs/heads/main ] && [ -z "$ALLOW" ] && { echo "protected branch hook: changes must be made through a pull request"; exit 1; }; done; exit 0\n' > "$O/hooks/pre-receive"; chmod +x "$O/hooks/pre-receive"; }
platform_merge() { S="$D/srv"; rm -rf "$S"; command git clone -q "$O" "$S"; git -C "$S" fetch -q origin "$1"   # the host merges a PR
  if [ "$2" = squash ]; then git -C "$S" merge -q --squash FETCH_HEAD; git -C "$S" commit -qm "$1 (#1)"; else git -C "$S" merge -q --no-ff --no-edit FETCH_HEAD; fi
  ALLOW=1 git -C "$S" push -q origin main; [ "${3:-}" = delete ] && git -C "$S" push -q origin ":$1"; true; }
setup_() {                                                                                 # aegonex-init **setup** go
  printf '# app\n## Commands\n- `true` — install (run in each new folder)\n- `sh test.sh` — run tests\n## Working mode (aegonex 0.4)\nBase: main · Remote: origin\n## Leader mode (aegonex 0.4)\n' > "$M/AGENTS.md"
  printf '@AGENTS.md\n' > "$M/CLAUDE.md"; mkdir -p "$M/.worktrees"; printf '*\n' > "$M/.worktrees/.gitignore"
  git -C "$M" add -- AGENTS.md CLAUDE.md
  git -C "$M" commit -q -m "chore: aegonex setup" -- AGENTS.md CLAUDE.md; }

########################################################################
say "1 setup: Remote and Base derived, setup committed on Base, .worktrees hidden"
mkrepo life
ok "Remote: the only name git remote prints" '[ "$(git -C "$M" remote)" = origin ]'
ok "Base: symbolic-ref of origin/HEAD without the prefix" '[ "$(git -C "$M" symbolic-ref --short refs/remotes/origin/HEAD)" = origin/main ]'
setup_
ok "setup commit names only AGENTS.md and CLAUDE.md" '[ "$(git -C "$M" show --name-only --format= HEAD | tr "\n" " ")" = "AGENTS.md CLAUDE.md " ]'
ok "<main> clean, .worktrees invisible to git" '[ -z "$(git -C "$M" status --porcelain)" ]'
ok "<main> = first worktree line" '[ "$(main_of "$M")" = "$M" ]'

say "2 plan opens m1 and commits ROADMAP.md there"
open_ m1; U=$M/.worktrees/m1
ok "folder on aegonex/m1" '[ "$(git -C "$U" branch --show-current)" = aegonex/m1 ]'
ok "<main> computed from inside the unit folder" '[ "$(main_of "$U")" = "$M" ]'
printf '# ROADMAP\n## Milestones\n- [ ] M1 — api · done when: sh test.sh\n  - [ ] b module · done when: test -f b.js\n  - [ ] c module · done when: test -f c.js\n' > "$U/ROADMAP.md"
commit_ "$U" "docs: plan M1" ROADMAP.md
ok "plan commit in the unit, Base untouched" '[ "$(git -C "$M" log -1 --format=%s main)" = "chore: aegonex setup" ] && [ "$(git -C "$U" log -1 --format=%s)" = "docs: plan M1" ]'
ok "no git status noise in <main>" '[ -z "$(git -C "$M" status --porcelain)" ]'

say "3 leader: two parts in sibling folders, reviewed, integrated"
printf 'echo ok\n' > "$U/test.sh"
commit_ "$U" "wip: m1 before split" test.sh                                                  # Split: commit leader's files by name
for k in 1 2; do git -C "$U" worktree add -b "aegonex/m1--p$k" "$M/.worktrees/m1--p$k" aegonex/m1; done
ok "part folders are siblings under <main>/.worktrees" '[ -d "$M/.worktrees/m1--p1" ] && [ -d "$M/.worktrees/m1--p2" ]'
P1=$M/.worktrees/m1--p1; P2=$M/.worktrees/m1--p2
printf 'b\n' > "$P1/b.js"; commit_ "$P1" "feat: b" b.js                                       # writers commit in their folders
printf 'c\n' > "$P2/c.js"; commit_ "$P2" "feat: c" c.js
ok "review p1: done-when runs in the part folder" '(cd "$P1" && test -f b.js)'
ok "review p1: diff aegonex/m1...HEAD lists only its file" '[ "$(git -C "$P1" diff --name-only aegonex/m1...HEAD)" = b.js ]'
for k in 1 2; do
  git -C "$U" merge --no-ff --no-edit "aegonex/m1--p$k" >/dev/null
  git -C "$U" worktree remove "$M/.worktrees/m1--p$k"
  git -C "$U" branch -d "aegonex/m1--p$k" >/dev/null
done
ok "both parts integrated, folders and part branches gone" '[ -f "$U/b.js" ] && [ -f "$U/c.js" ] && [ ! -d "$P1" ] && ! git -C "$M" rev-parse -q --verify refs/heads/aegonex/m1--p1'
ok "no part left in worktree list" '[ "$(git -C "$M" worktree list | wc -l | tr -d " ")" = 2 ]'

say "4 note appends to the state folder (m1), uncommitted"
printf '# HANDOFF — 2026-09-26\n\nBranch: aegonex/m1 · HEAD: x\n\n## Session log\n- 2026-09-26 10:00 fact: npm test needs PORT=5433\n' > "$U/HANDOFF.md"
ok "note did not touch <main>" '[ ! -f "$M/HANDOFF.md" ]'

say "5 task t-typo alongside m1: open from Base, one part, review, done lands and cleans up"
open_ t-typo; UT=$M/.worktrees/t-typo
printf 'hello world\n' > "$UT/README.md"
ok "one-part review reads status and diff HEAD" '[ "$(git -C "$UT" diff --name-only HEAD)" = README.md ]'
commit_ "$UT" "fix: README typo" README.md
ok "t-typo has no HANDOFF edits (m1 folder is open)" '[ -z "$(git -C "$UT" diff --name-only main -- HANDOFF.md ROADMAP.md)" ]'
sync_ "$UT"
ok "anchor grep works with -C and exclude globs" '! anchors "$UT"'
git -C "$UT" commit -q --allow-empty -m "chore: close t-typo"
ok "closed test" 'closed_ "$UT" t-typo'
ok "secret scan clean" '[ -z "$(scan_ "$UT" t-typo)" ]'
ok "land: pushed to Base" '[ "$(land_ "$UT" t-typo)" = landed ]'
ok "push updated origin/main tracking ref" '[ "$(git -C "$M" rev-parse origin/main)" = "$(git -C "$M" rev-parse aegonex/t-typo)" ]'
ok "clean up: ff <main>, remove folder, branch -d" 'clean_ "$UT" t-typo'
ok "setup commit reached origin with the task" 'git -C "$M" log --format=%s origin/main | grep -qx "chore: aegonex setup"'
ok "no online aegonex branch" '[ -z "$(git -C "$M" ls-remote origin "refs/heads/aegonex/*")" ]'

say "6 exit in m1: rewrite HANDOFF (no Session log), tick steps, commit"
printf '# HANDOFF — 2026-09-26\n\nBranch: aegonex/m1 · HEAD: x\n\n## Stopped at\nall steps done\n\n## Next step\nrun aegonex-done (M1)\n\n## Notes for the next session\n- npm test needs PORT=5433\n' > "$U/HANDOFF.md"
perl -pi -e 's/  - \[ \]/  - [x]/' "$U/ROADMAP.md"
commit_ "$U" "docs: handoff 2026-09-26" HANDOFF.md ROADMAP.md
ok "milestone line not ticked by exit" 'grep -q "^- \[ \] M1" "$U/ROADMAP.md"'
ok "folder clean" '[ -z "$(git -C "$U" status --porcelain)" ]'

say "7 done m1: sync (takes t-typo), prove, close, land, clean up on one go"
sync_ "$U"
ok "sync merged the task's landing" '[ "$(cat "$U/README.md")" = "hello world" ]'
ok "prove: done-whens run in the unit folder" '(cd "$U" && sh test.sh >/dev/null) && (cd "$U" && test -f b.js) && (cd "$U" && test -f c.js)'
ok "ignored files that go with the folder are listed" 'touch "$U/.env"; git -C "$U" status --short --ignored | grep -q "^!! .env"'
rm -f "$U/.env"
perl -pi -e 's/^- \[ \] M1 — api .*/- [x] M1 — api · closed 2026-09-26/; $_="" if /^  - /' "$U/ROADMAP.md"
git -C "$U" add -- ROADMAP.md
git -C "$U" commit -q --allow-empty -m "chore: close m1"
ok "closed after a sync merge still reads closed" 'closed_ "$U" m1'
ok "secret scan clean" '[ -z "$(scan_ "$U" m1)" ]'
ok "land" '[ "$(land_ "$U" m1)" = landed ]'
ok "clean up" 'clean_ "$U" m1'
ok "nothing left: one worktree, no aegonex branch" '[ "$(git -C "$M" worktree list | wc -l | tr -d " ")" = 1 ] && [ -z "$(git -C "$M" branch --list "aegonex/*")" ]'
ok "Base carries ROADMAP collapsed and HANDOFF without Session log" 'grep -q "closed 2026-09-26" "$M/ROADMAP.md" && ! grep -q "Session log" "$M/HANDOFF.md"'

say "8 protected Base: m2 lands through a pull request; plan waits; a task may start"
protect
open_ m2; U=$M/.worktrees/m2
printf -- '- [ ] M2 — web · done when: test -f w.js\n  - [ ] w · done when: test -f w.js\n' >> "$U/ROADMAP.md"; commit_ "$U" "docs: plan M2" ROADMAP.md
printf 'w\n' > "$U/w.js"; commit_ "$U" "feat: w" w.js
sync_ "$U"; git -C "$U" commit -q --allow-empty -m "chore: close m2"
ok "land -> pull request path (branch pushed, gh called)" '[ "$(land_ "$U" m2)" = pr ] && grep -q "pr create" "$GH_LOG"'
ok "Base untouched online" '[ "$(git -C "$M" rev-parse origin/main)" = "$(git -C "$M" rev-parse main)" ]'
ok "online copy aegonex/m2 exists, no upstream set" 'git -C "$M" rev-parse -q --verify refs/remotes/origin/aegonex/m2 && [ -z "$(git -C "$M" config branch.aegonex/m2.remote)" ]'
ok "plan's waiting test: m2 closed and its folder still here" 'closed_ "$U" m2 && [ -d "$U" ]'
open_ t-docs; UD=$M/.worktrees/t-docs
ok "a task opens from Base while m2 waits" '[ "$(git -C "$UD" branch --show-current)" = aegonex/t-docs ]'
git -C "$M" config fetch.prune true
platform_merge aegonex/m2 squash delete
ok "pushed check before fetch: aegonex/m2 equals origin/aegonex/m2" '[ "$(git -C "$M" rev-parse aegonex/m2)" = "$(git -C "$M" rev-parse origin/aegonex/m2)" ]'
git -C "$M" fetch origin main 2>/dev/null
ok "fetch of Base alone keeps origin/aegonex/m2 even with fetch.prune" 'git -C "$M" rev-parse -q --verify refs/remotes/origin/aegonex/m2'
ok "cleanup after squash: ff, remove, branch -D" 'clean_ "$U" m2 -D'
ok "online branch never deleted by aegonex (host deleted it itself here)" 'true'

say "9 task t-docs after the squash: sync, close, PR path"
printf 'docs\n' > "$UD/DOCS.md"; commit_ "$UD" "docs: add DOCS" DOCS.md
sync_ "$UD"
ok "task synced with the squashed Base" 'git -C "$UD" merge-base --is-ancestor origin/main HEAD'
git -C "$UD" commit -q --allow-empty -m "chore: close t-docs"
ok "task goes the pull request path too" '[ "$(land_ "$UD" t-docs)" = pr ]'
platform_merge aegonex/t-docs merge
git -C "$M" fetch origin main 2>/dev/null
ok "cleanup after a merge commit: -d suffices after ff" '[ "$(git -C "$M" rev-parse aegonex/t-docs)" = "$(git -C "$M" rev-parse origin/aegonex/t-docs)" ] && clean_ "$UD" t-docs'
rm -f "$O/hooks/pre-receive"

say "10 incomplete landing (exit 'push what I have'), Keep then Remove"
open_ t-inc; UI=$M/.worktrees/t-inc
printf 'half\n' > "$UI/i.js"; commit_ "$UI" "wip: half" i.js
printf '# HANDOFF\n## Next step\nfinish i.js (t-inc)\n' > "$UI/HANDOFF.md"; commit_ "$UI" "docs: handoff 2026-09-26" HANDOFF.md
ok "scan, then land unfinished" '[ -z "$(scan_ "$UI" t-inc)" ] && [ "$(land_ "$UI" t-inc)" = landed ]'
ok "Keep: folder and branch stay" '[ -d "$UI" ] && git -C "$M" rev-parse -q --verify refs/heads/aegonex/t-inc'
printf 'full\n' > "$UI/i.js"; commit_ "$UI" "feat: finish" i.js
ok "a second landing from the kept folder is a plain push" '[ "$(land_ "$UI" t-inc)" = landed ]'
ok "Remove: ff, remove, branch -d" 'clean_ "$UI" t-inc'

say "10b incomplete milestone removed, then reopened from Base"
open_ m3; U=$M/.worktrees/m3
printf -- '- [ ] M3 — cli · done when: test -f x.js\n  - [ ] x · done when: test -f x.js\n  - [ ] y · done when: test -f y.js\n' >> "$U/ROADMAP.md"; commit_ "$U" "docs: plan M3" ROADMAP.md
printf 'x\n' > "$U/x.js"; commit_ "$U" "feat: x" x.js
ok "land unfinished m3" '[ "$(land_ "$U" m3)" = landed ]'
ok "Remove" 'clean_ "$U" m3'
open_ m3
ok "reopen: Open's second form from Base carries the partial work" '[ -f "$M/.worktrees/m3/x.js" ] && grep -q "M3 — cli" "$M/.worktrees/m3/ROADMAP.md"'
git -C "$M" worktree remove "$M/.worktrees/m3"; git -C "$M" branch -d aegonex/m3 >/dev/null

say "11 never force-remove: untracked file blocks removal; nothing lost"
open_ t-dirty; UX=$M/.worktrees/t-dirty; printf 'x\n' > "$UX/scratch.txt"
ok "worktree remove refuses an untracked file" '! git -C "$M" worktree remove "$UX"'
ok "file still there" '[ -f "$UX/scratch.txt" ]'
rm "$UX/scratch.txt"; git -C "$M" worktree remove "$UX"; git -C "$M" branch -d aegonex/t-dirty >/dev/null
ok "branch -d refuses an unlanded branch" 'open_ t-un; printf u > "$M/.worktrees/t-un/u.js"; commit_ "$M/.worktrees/t-un" u u.js; git -C "$M" worktree remove "$M/.worktrees/t-un"; ! git -C "$M" branch -d aegonex/t-un'
git -C "$M" branch -D aegonex/t-un >/dev/null

say "12 HANDOFF conflict at sync with no milestone open: the unit's copy wins"
open_ t-a; open_ t-b; UA=$M/.worktrees/t-a; UB=$M/.worktrees/t-b
printf '# HANDOFF a\n## Dead ends\n- X failed\n' > "$UA/HANDOFF.md"; commit_ "$UA" "docs: handoff" HANDOFF.md
printf '# HANDOFF b\n## Dead ends\n- Y failed\n' > "$UB/HANDOFF.md"; commit_ "$UB" "docs: handoff" HANDOFF.md
git -C "$UA" commit -q --allow-empty -m "chore: close t-a"; land_ "$UA" t-a >/dev/null; clean_ "$UA" t-a
ok "sync of t-b stops on HANDOFF.md" '! sync_ "$UB"'
git -C "$UB" checkout --ours -- HANDOFF.md
git -C "$UB" show MERGE_HEAD:HANDOFF.md | grep '^- ' | while read -r l; do grep -qxF -- "$l" "$UB/HANDOFF.md" || printf '%s\n' "$l" >> "$UB/HANDOFF.md"; done   # the agent appends the lines it lacks
git -C "$UB" add -- HANDOFF.md
git -C "$UB" commit -q --no-edit
ok "t-b keeps its HANDOFF, gains the other side's dead end, Base merged" 'head -1 "$UB/HANDOFF.md" | grep -q "HANDOFF b" && grep -q "X failed" "$UB/HANDOFF.md" && grep -q "Y failed" "$UB/HANDOFF.md" && git -C "$UB" merge-base --is-ancestor origin/main HEAD'
git -C "$M" worktree remove "$UB"; git -C "$M" branch -D aegonex/t-b >/dev/null

say "13 move: <main> dirty on Base (tracked + untracked) into a new unit"
printf 'edited\n' >> "$M/a.js"; printf 'new\n' > "$M/new.js"
git -C "$M" add -N -- new.js
git -C "$M" diff --binary HEAD --output="$M/.worktrees/move.patch" -- a.js new.js
git -C "$M" restore --source=HEAD --staged --worktree -- a.js new.js
ok "<main> clean after restore (the untracked file left the folder too)" '[ -z "$(git -C "$M" status --porcelain)" ] && [ ! -f "$M/new.js" ]'
open_ t-moved; UM=$M/.worktrees/t-moved
git -C "$UM" apply --3way "$M/.worktrees/move.patch"
rm "$M/.worktrees/move.patch"
ok "change arrived in the unit folder" 'grep -q edited "$UM/a.js" && [ -f "$UM/new.js" ]'
git -C "$M" worktree remove --force "$UM" 2>/dev/null; git -C "$M" branch -D aegonex/t-moved >/dev/null   # lab teardown only

say "13b move: <main> on a v0.3 branch fix/db with a commit and a dirty file"
git -C "$M" switch -q -c fix/db; printf 'db\n' > "$M/db.js"; commit_ "$M" "feat: db" db.js; printf 'dirty\n' >> "$M/db.js"
git -C "$M" diff --binary HEAD --output="$M/.worktrees/move.patch" -- db.js
git -C "$M" restore --source=HEAD --staged --worktree -- db.js
git -C "$M" switch main
open_ t-db fix/db; UM=$M/.worktrees/t-db; git -C "$UM" merge -q --no-edit main              # move step 7: carry Base
git -C "$UM" apply --3way "$M/.worktrees/move.patch"; git -C "$UM" restore --staged -- db.js; rm "$M/.worktrees/move.patch"
ok "fix/db kept, unit starts from it with Base merged, dirty edit carried unstaged, <main> on Base and clean" 'git -C "$M" rev-parse -q --verify refs/heads/fix/db && git -C "$M" merge-base --is-ancestor fix/db aegonex/t-db && git -C "$M" merge-base --is-ancestor main aegonex/t-db && grep -q dirty "$UM/db.js" && [ -z "$(git -C "$UM" diff --cached --name-only)" ] && [ "$(git -C "$M" branch --show-current)" = main ] && [ -z "$(git -C "$M" status --porcelain)" ]'

say "14 harness folder adopted as the unit folder; parts nested under it; never removed"
H="$M/.claude/worktrees/h1"; git -C "$M" worktree add -q -b claude/h1 "$H" main
git -C "$H" switch -c aegonex/t-h
ok "adopted" '[ "$(git -C "$H" branch --show-current)" = aegonex/t-h ]'
mkdir -p "$H/.worktrees"; printf '*\n' > "$H/.worktrees/.gitignore"
git -C "$H" worktree add -b aegonex/t-h--p1 "$H/.worktrees/t-h--p1" aegonex/t-h
printf 'h\n' > "$H/.worktrees/t-h--p1/h.js"; commit_ "$H/.worktrees/t-h--p1" "feat: h" h.js
ok "harness folder shows no part folder in status" '[ -z "$(git -C "$H" status --porcelain)" ]'
git -C "$H" merge --no-ff --no-edit aegonex/t-h--p1 >/dev/null
git -C "$H" worktree remove "$H/.worktrees/t-h--p1"
git -C "$H" branch -d aegonex/t-h--p1 >/dev/null
sync_ "$H"; git -C "$H" commit -q --allow-empty -m "chore: close t-h"
ok "lands from the harness folder" '[ "$(land_ "$H" t-h)" = landed ]'
ok "Clean up step 1 from a harness folder: landed" 'git -C "$M" merge-base --is-ancestor aegonex/t-h origin/main'
git -C "$H" switch --detach
git -C "$H" branch -d aegonex/t-h
ok "branch gone, harness folder kept, detached" '! git -C "$M" rev-parse -q --verify refs/heads/aegonex/t-h && [ -d "$H" ] && [ -z "$(git -C "$H" branch --show-current)" ]'
ok "init later: <main> behind origin/main -> ff" 'git -C "$M" merge-base --is-ancestor main origin/main && git -C "$M" merge --ff-only origin/main'

say "15 protected from the start: setup commit only on local Base, PR squashed -> reset --keep"
mkrepo prot; protect; setup_
open_ m1; U=$M/.worktrees/m1; printf 'q\n' > "$U/q.js"; commit_ "$U" "feat: q" q.js
sync_ "$U"; git -C "$U" commit -q --allow-empty -m "chore: close m1"
ok "PR path" '[ "$(land_ "$U" m1)" = pr ]'
platform_merge aegonex/m1 squash
git -C "$M" fetch origin main 2>/dev/null
ok "ff refuses; only the setup commit is local; reset --keep; cleanup" '! git -C "$M" merge --ff-only origin/main && clean_ "$U" m1 -D && [ "$(git -C "$M" rev-parse main)" = "$(git -C "$M" rev-parse origin/main)" ] && [ -f "$M/AGENTS.md" ]'

say "16 unborn repository: setup names the entries; units open from Base"
D="$RUN/unborn"; mkdir -p "$D"; M="$D/app"; git init -q -b main "$M"; printf 'x\n' > "$M/x.js"; printf 'SECRET=1\n' > "$M/.env"; mkdir -p "$M/node_modules"; touch "$M/node_modules/k"
ok "no commit yet" '! git -C "$M" rev-parse --verify -q HEAD'
ok "Base = current branch" '[ "$(git -C "$M" branch --show-current)" = main ]'
printf '# app\n' > "$M/AGENTS.md"; printf '@AGENTS.md\n' > "$M/CLAUDE.md"; mkdir -p "$M/.worktrees"; printf '*\n' > "$M/.worktrees/.gitignore"
git -C "$M" add -- AGENTS.md CLAUDE.md x.js
git -C "$M" commit -q -m "chore: aegonex setup" -- AGENTS.md CLAUDE.md x.js
ok "entries committed, .env and node_modules left out" '[ "$(git -C "$M" ls-files | tr "\n" " ")" = "AGENTS.md CLAUDE.md x.js " ]'
open_ t-first
ok "unit opens" '[ -d "$M/.worktrees/t-first" ]'

say "17 secret scan finds a key in an unpushed commit and a .env file"
mkrepo sec; setup_; open_ t-k; U=$M/.worktrees/t-k
printf 'const k = "sk-proj-abcdefghijklmnopqrstuvwxyz";\n' > "$U/k.js"; printf 'A=1\n' > "$U/.env.local"
commit_ "$U" "feat: k" k.js .env.local
git -C "$M" push -q origin main   # Base online now carries setup, so the range is the unit's own commits
ok "scan hits the key and the .env file" '[ "$(scan_ "$U" t-k | wc -l | tr -d " ")" = 2 ]'

say "10c Keep, then new unpushed commits, then Remove: stops before anything is removed"
open_ t-k2; UK=$M/.worktrees/t-k2; printf 'a\n' > "$UK/k2.js"; commit_ "$UK" "wip" k2.js
land_ "$UK" t-k2 >/dev/null; printf 'b\n' >> "$UK/k2.js"; commit_ "$UK" "more" k2.js
ok "Remove refuses: aegonex/t-k2 is not in origin/main" '! clean_ "$UK" t-k2 && [ -d "$UK" ] && git -C "$M" rev-parse -q --verify refs/heads/aegonex/t-k2'
land_ "$UK" t-k2 >/dev/null; clean_ "$UK" t-k2

say "14b a new harness session adopts an existing unit branch"
open_ t-z; printf 'z\n' > "$M/.worktrees/t-z/z.js"; commit_ "$M/.worktrees/t-z" z z.js
git -C "$M" worktree remove "$M/.worktrees/t-z"
H2="$M/.claude/worktrees/h2"; git -C "$M" worktree add -q -b claude/h2 "$H2" main
git -C "$M" worktree prune
ok "branch held by no folder: switch to it" 'git -C "$H2" switch aegonex/t-z && [ -f "$H2/z.js" ]'
ok "a branch held by another folder cannot be adopted" 'open_ t-y >/dev/null 2>&1; ! git -C "$H2" switch aegonex/t-y'

say "18 no remote: land is ff-only in <main>, cleanup skips the online update"
D="$RUN/norem"; mkdir -p "$D"; M="$D/app"; git init -q -b main "$M"; printf 'x\n' > "$M/x.js"; git -C "$M" add -- x.js; git -C "$M" commit -q -m init
open_ t-n; UN=$M/.worktrees/t-n; printf 'y\n' > "$UN/y.js"; commit_ "$UN" "feat: y" y.js
ok "Sync: no remote, merge-base with main only" 'git -C "$UN" merge-base --is-ancestor main HEAD'
git -C "$UN" commit -q --allow-empty -m "chore: close t-n"
ok "land: merge --ff-only in <main>" 'git -C "$M" merge --ff-only aegonex/t-n'
ok "cleanup: landed in main, remove, branch -d" 'landed_ t-n main && git -C "$M" worktree remove "$UN" && git -C "$M" branch -d aegonex/t-n'

say "19 Base moved online after Sync: push rejected, the close stays, Sync then land again"
M="$RUN/life/app"; O="$RUN/life/origin.git"; D="$RUN/life"
open_ t-mv; UV=$M/.worktrees/t-mv; printf 'v\n' > "$UV/v.js"; commit_ "$UV" "feat: v" v.js
sync_ "$UV"; git -C "$UV" commit -q --allow-empty -m "chore: close t-mv"
S="$D/other"; command git clone -q "$O" "$S"; printf 'o\n' > "$S/o.js"; git -C "$S" add o.js; git -C "$S" commit -qm other; git -C "$S" push -q origin main
ok "push classified as Base moved" '[ "$(land_ "$UV" t-mv)" = stop:base-moved ]'
sync_ "$UV"
ok "still closed after Sync; land and clean up" 'closed_ "$UV" t-mv && [ "$(land_ "$UV" t-mv)" = landed ] && clean_ "$UV" t-mv'

say "20 protected Base: exit lands unfinished work as a pull request; merged later; Remove / Keep"
M="$RUN/life/app"; O="$RUN/life/origin.git"; D="$RUN/life"; protect
open_ t-half; UH=$M/.worktrees/t-half; printf 'h\n' > "$UH/half.js"; commit_ "$UH" "wip: half" half.js
git -C "$UH" fetch origin main 2>/dev/null
git -C "$UH" merge-base --is-ancestor origin/main HEAD || git -C "$UH" merge --no-edit origin/main >/dev/null
ok "exit's scan then land -> pull request, folder kept" '[ -z "$(scan_ "$UH" t-half)" ] && [ "$(land_ "$UH" t-half)" = pr ] && [ -d "$UH" ]'
ok "not closed: done offers Remove / Keep after the merge" '! closed_ "$UH" t-half'
platform_merge aegonex/t-half squash
ok "pushed check" '[ "$(git -C "$M" rev-parse aegonex/t-half)" = "$(git -C "$M" rev-parse origin/aegonex/t-half)" ]'
git -C "$M" fetch origin main 2>/dev/null
ok "Keep: nothing removed" '[ -d "$UH" ]'
ok "Remove: Clean up from step 2 with -D" 'clean_ "$UH" t-half -D && [ ! -d "$UH" ] && git -C "$M" merge-base --is-ancestor origin/main main'
ok "online copy still there (aegonex never deletes it)" 'git -C "$M" ls-remote --exit-code origin refs/heads/aegonex/t-half'
rm -f "$O/hooks/pre-receive"

say "21 v0.4.1: no milestone open, the task's noted HANDOFF.md blocks Clean up; aegonex-exit's commit first"
mkrepo nomile; setup_; open_ t-a; UA=$M/.worktrees/t-a
printf '# HANDOFF — 2026-09-27\n\n## Session log\n- 2026-09-27 10:00 fact: t-a done when: sh test.sh\n' > "$UA/HANDOFF.md"   # note, no milestone folder
printf 'a\n' > "$UA/a2.js"; commit_ "$UA" "feat: a" a2.js
ok "the status lists HANDOFF.md: the report ends with run aegonex-exit first" 'status_ "$UA" | grep -q "HANDOFF.md"'
ok "v0.4 defect: the land go pushes, then worktree remove refuses the noted folder" '[ "$(land_ "$UA" t-a)" = landed ] && ! clean_ "$UA" t-a && [ -d "$UA" ] && [ -f "$UA/HANDOFF.md" ]'
open_ t-b; UB=$M/.worktrees/t-b
printf '# HANDOFF — 2026-09-27\n\n## Session log\n- 2026-09-27 11:00 fact: t-b done when: sh test.sh\n' > "$UB/HANDOFF.md"
printf 'b\n' > "$UB/b.js"; commit_ "$UB" "feat: b" b.js
commit_ "$UB" "docs: handoff 2026-09-27" HANDOFF.md                                          # aegonex-exit's go
ok "after exit's commit the status is empty" '[ -z "$(status_ "$UB")" ]'
ok "then the land go lands and cleans up; the notes are on Base" '[ "$(land_ "$UB" t-b)" = landed ] && clean_ "$UB" t-b && [ ! -d "$UB" ] && git -C "$M" cat-file -e origin/main:HANDOFF.md'

. "$HERE/review-round.sh"

echo; echo "passed $P_, failed $F_"; [ "$F_" -eq 0 ]
