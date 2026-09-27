#!/bin/bash
# v0.5 lab: a plain folder holding several repos. Every git line is a command of references/repos.md or of the
# v0.4 recipes it runs per repo, with the placeholders filled in (<P>=$P, <r>, <Base>=main, <remote>=origin).
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
RUN=${AEGONEX_RUN:-$(mktemp -d "${TMPDIR:-/tmp}/aegonex-multi.XXXXXX")} && mkdir -p "$RUN" && RUN=$(cd "$RUN" && pwd -P) && [ -n "$RUN" ] && [ "$RUN" != / ] \
  || { echo "multi-repo: cannot make a run folder (set AEGONEX_RUN)" >&2; exit 1; }
command git -C "$RUN" rev-parse --git-dir >/dev/null 2>&1 && { echo "multi-repo: $RUN is inside a git repo; set AEGONEX_RUN" >&2; exit 1; }
export GIT_CEILING_DIRECTORIES="$RUN" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=lab GIT_AUTHOR_EMAIL=l@x.io GIT_COMMITTER_NAME=lab GIT_COMMITTER_EMAIL=l@x.io
echo "run folder: $RUN"
P_=0; F_=0
ok() { if eval "$2" >/dev/null 2>&1; then echo "  ok   $1"; P_=$((P_+1)); else echo "  FAIL $1"; F_=$((F_+1)); fi; }
say() { echo "== $*"; }
build() { D="$RUN/$1"; shift; bash "$HERE/fixtures/make-multi-fixture.sh" "$D" "$@" >"$RUN/fixture.log" 2>&1 \
  || { cat "$RUN/fixture.log"; echo "multi-repo: fixture failed" >&2; exit 1; }; P="$D/shop"; }

# ---------- repos.md recipes ----------
is_repo() { [ "$(git -C "$1" rev-parse --show-prefix --git-dir 2>/dev/null)" = "$(printf '\n.git')" ]; }   # section 1
landed() { S="$P/$1"; v=$2                                                                                  # section 3
  git -C "$S" rev-parse --verify -q "refs/heads/aegonex/$v" >/dev/null && return 1
  case "$v" in m*) k=${v#m}; git -C "$S" grep -q -E "^- \[x\] M$k .* closed [0-9]{4}-[0-9]{2}-[0-9]{2}" origin/main -- ROADMAP.md;; *) return 0;; esac; }
open_() { a="$P/$1"; git -C "$a" worktree prune; git -C "$a" worktree add -q -b "aegonex/$2" "$a/.worktrees/$2" main; }   # **Open**
commit_() { f=$1; msg=$2; shift 2; git -C "$f" add -- "$@"; git -C "$f" commit -q -m "$msg" -- "$@"; }
land_() { git -C "$1" push -q origin "aegonex/$2:main" 2>"$RUN/push.err"; }                                 # **Land**
update_() { M=$1                                                                                            # done 7.4.2, v0.5
  git -C "$M" merge -q --ff-only origin/main 2>/dev/null && return 0
  lg=$(git -C "$M" log --format=%s origin/main..main)
  [ -n "$lg" ] && [ -z "$(echo "$lg" | grep -vx 'chore: aegonex setup')" ] || return 1
  git -C "$M" grep -q -F "## Working mode (aegonex 0.4)" origin/main -- AGENTS.md || return 1
  if grep -q -F "## Repos (aegonex 0.5)" "$M/AGENTS.md"; then git -C "$M" grep -q -F "## Repos (aegonex 0.5)" origin/main -- AGENTS.md || return 2; fi
  git -C "$M" reset -q --keep origin/main; }                                                                 # 2: that heading alone not online
clean_() { M="$P/$1"; u=$2; flag=${3:--d}                                                                    # **Clean up**
  [ "$flag" = -D ] || git -C "$M" merge-base --is-ancestor "aegonex/$u" origin/main || return 1
  update_ "$M"; rc=$?; [ "$rc" = 1 ] && return 1; [ "$rc" = 2 ] && flag=-D
  git -C "$M" worktree remove "$M/.worktrees/$u" || return 1
  git -C "$M" branch -q "$flag" "aegonex/$u"; }
close_m() { a="$P/$1"; u=$2; k=${u#m}; f="$a/.worktrees/$u"                                                  # done's go for a milestone
  perl -0pi -e "s/^- \\[ \\] M$k — ([^·\\n]*?) ·[^\\n]*\\n(  - [^\\n]*\\n)*/- [x] M$k — \$1 · closed 2026-09-27\\n/m" "$f/ROADMAP.md"
  git -C "$f" add -- ROADMAP.md; git -C "$f" commit -q --allow-empty -m "chore: close $u"; }

say "1 find the repos: repo roots only; the parent itself is not a repo"
build find
ok "the parent's worktree list fails with not a git repository" '! git -C "$P" worktree list --porcelain 2>"$RUN/wl.err" && grep -q "not a git repository" "$RUN/wl.err"'
ok "backend, frontend and admin are repos" 'is_repo "$P/backend" && is_repo "$P/frontend" && is_repo "$P/admin"'
ok "docs/ is not (exit 128, not a git repository)" 'git -C "$P/docs" rev-parse --show-prefix --git-dir 2>"$RUN/d.err"; [ $? -eq 128 ] && grep -q "not a git repository" "$RUN/d.err"'
ok "a linked worktree is not a repo root (absolute git dir)" '! is_repo "$P/backend/.worktrees/m3"'
ok "a subfolder of a repo is not (non-empty prefix)" '! is_repo "$P/backend/src"'
ok "the fixture wrote nothing in shop but the repos, docs/ and notes.txt" '[ "$(ls -A "$P" | tr "\n" " ")" = "admin backend docs frontend notes.txt " ]'

say "2 landed check: a milestone lands when its branch is gone and its closed line is online"
ok "frontend m5 waits: backend m3 has a branch" '! landed backend m3'
f="$P/backend/.worktrees/m3"; perl -pi -e 's/- \[ \] step 3/- [x] step 3/' "$f/ROADMAP.md"; commit_ "$f" "feat: step 3" ROADMAP.md
close_m backend m3
ok "closed but not pushed: not landed" '! landed backend m3'
land_ "$f" m3
ok "pushed, the line online, the branch still there: not landed" '! landed backend m3 && git -C "$P/backend" grep -q -E "^- \[x\] M3 .* closed" origin/main -- ROADMAP.md'
ok "the push updated origin/main without a fetch" 'git -C "$P/backend" merge-base --is-ancestor aegonex/m3 origin/main'
cd "$P/backend"; clean_ backend m3; cd "$P"
ok "after Clean up: landed" 'landed backend m3'
ok "M3 never matches M30" 'printf "# R\n- [x] M30 — big · closed 2026-01-01\n" > "$RUN/r30" && ! grep -q -E "^- \[x\] M3 .* closed [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$RUN/r30"'
ok "a task lands when its branch is gone; one never opened reads the same, so records are written only while it exists" 'landed backend t-none'
ok "nothing was written in shop" '[ "$(ls -A "$P" | tr "\n" " ")" = "admin backend docs frontend notes.txt " ]'

say "3 squash-merged pull request: step 8's fetch and -D, then the consumer's check passes"
build squash --protected backend --ticked
f="$P/backend/.worktrees/m3"; close_m backend m3
ok "the protected push is refused" '! land_ "$f" m3 && grep -q protected "$RUN/push.err"'
git -C "$f" push -q origin aegonex/m3
S="$D/srv"; git clone -q "$D/remotes/backend.git" "$S"; git -C "$S" fetch -q origin aegonex/m3
git -C "$S" merge -q --squash FETCH_HEAD; git -C "$S" commit -qm "M3 (#1)"; ALLOW=1 git -C "$S" push -q origin main
ok "waiting for the merge: frontend m5 does not land" '! landed backend m3'
git -C "$P/backend" fetch -q origin main; cd "$P/backend"; clean_ backend m3 -D; cd "$P"
ok "after step 8 (squash, -D): landed" 'landed backend m3'

say "4 cross-repo task: a refused provider stops the consumer"
build refused --protected backend --no-milestones
open_ backend t-discount; open_ frontend t-discount
printf 'export const DISCOUNT = 0;\n' > "$P/backend/.worktrees/t-discount/src/discount.js"; commit_ "$P/backend/.worktrees/t-discount" "feat: discount" src/discount.js
printf 'export const SHOW = true;\n' > "$P/frontend/.worktrees/t-discount/src/show.js"; commit_ "$P/frontend/.worktrees/t-discount" "feat: show" src/show.js
ok "frontend t-discount waits for backend t-discount" '! landed backend t-discount'
ok "backend's land is refused as protected" '! land_ "$P/backend/.worktrees/t-discount" t-discount'
ok "so frontend is not landed: nothing pushed there" '! landed backend t-discount && ! grep -qs "^frontend" "$D/push-order.log"'
rm -f "$D/remotes/backend.git/hooks/pre-receive"
ok "provider first: backend lands and cleans up" 'land_ "$P/backend/.worktrees/t-discount" t-discount && (cd "$P/backend" && clean_ backend t-discount)'
ok "then the consumer's check passes and frontend lands" 'landed backend t-discount && land_ "$P/frontend/.worktrees/t-discount" t-discount && (cd "$P/frontend" && clean_ frontend t-discount)'
ok "push order: backend before frontend" '[ "$(cut -d" " -f1 "$D/push-order.log" | uniq | tr "\n" " ")" = "backend frontend " ]'

say "5 the Repos-section commit: a unit opened before it lands without it; 7.4.2 keeps the commit and Clean up goes on"
build setup --no-repos-section --no-milestones
b="$P/backend"; open_ backend t-early
printf '\n' >> "$b/AGENTS.md"; cat "$HERE/../skills/aegonex-init/assets/AGENTS-repos.md" >> "$b/AGENTS.md"
commit_ "$b" "chore: aegonex setup" AGENTS.md
printf 'x\n' > "$b/.worktrees/t-early/x.js"; commit_ "$b/.worktrees/t-early" "feat: x" x.js
land_ "$b/.worktrees/t-early" t-early
ok "v0.4's 7.4.2 alone would reset it away (Working mode online, only setup commits local)" 'git -C "$b" grep -q -F "## Working mode (aegonex 0.4)" origin/main -- AGENTS.md && [ "$(git -C "$b" log --format=%s origin/main..main)" = "chore: aegonex setup" ]'
ok "ff-only is refused" '! git -C "$b" merge -q --ff-only origin/main'
ok "v0.5: Clean up goes on without Update (-D): folder and branch gone, the Repos commit kept on main" '(cd "$b" && clean_ backend t-early) && [ ! -d "$b/.worktrees/t-early" ] && ! git -C "$b" rev-parse -q --verify aegonex/t-early && [ "$(git -C "$b" log -1 --format=%s main)" = "chore: aegonex setup" ] && grep -q "## Repos (aegonex 0.5)" "$b/AGENTS.md"'
open_ backend t-late; printf 'y\n' > "$b/.worktrees/t-late/y.js"; commit_ "$b/.worktrees/t-late" "feat: y" y.js
ok "the next unit opened from main carries the setup commit" 'git -C "$b" merge-base --is-ancestor main aegonex/t-late'
git -C "$b/.worktrees/t-late" merge -q --no-edit origin/main   # Sync: done step 2
ok "with Sync it lands; Clean up fast-forwards main; the Repos heading is online" 'land_ "$b/.worktrees/t-late" t-late && (cd "$b" && clean_ backend t-late) && git -C "$b" grep -q -F "## Repos (aegonex 0.5)" origin/main -- AGENTS.md && [ "$(git -C "$b" rev-parse main)" = "$(git -C "$b" rev-parse origin/main)" ]'

say "6 nested-repo guard: a git-init'ed parent lists its repos as untracked repo roots"
build nested --git-init-parent --no-milestones
ok "the parent's worktree list now succeeds (a v0.4 skill would treat shop as the project)" 'git -C "$P" worktree list --porcelain'
ok "its status lists ?? backend/, and backend/ is a repo root: init stops" 'git -C "$P" -c core.quotePath=false status --short | grep -qx "?? backend/" && is_repo "$P/backend"'

say "7 a noted HANDOFF.md in a task folder blocks Clean up (v0.4.1): exit first"
build noted --no-milestones
open_ frontend t-note; t="$P/frontend/.worktrees/t-note"
printf '# HANDOFF — 2026-09-27\n\n## Session log\n- 2026-09-27 10:00 fact: t-note after: backend t-note\n' > "$t/HANDOFF.md"
ok "its status lists HANDOFF.md" 'git -C "$t" status --short | grep -q HANDOFF.md'
commit_ "$t" "docs: handoff 2026-09-27" HANDOFF.md
ok "after exit's commit it lands and cleans up" 'land_ "$t" t-note && (cd "$P/frontend" && clean_ frontend t-note)'

say "8 review fixes: a CRLF ROADMAP line, a repo session's sibling path, a record that Sync brings in"
build crlf --no-milestones
b="$P/backend"; open_ backend m3
printf -- '- [x] M3 — cart discount API · closed 2026-09-27\r\n' >> "$b/.worktrees/m3/ROADMAP.md"; commit_ "$b/.worktrees/m3" "chore: close m3" ROADMAP.md
land_ "$b/.worktrees/m3" m3; (cd "$b" && clean_ backend m3)
ok "a CRLF closed line reads landed (no \$ anchor)" 'landed backend m3 && git -C "$b" show origin/main:ROADMAP.md | grep -q $'"'"'closed 2026-09-27\r'"'"
ok "M3 does not match M30 without the anchor either" '! printf -- "- [x] M30 — x · closed 2026-09-27\n" | grep -q -E "^- \[x\] M3 .* closed [0-9]{4}-[0-9]{2}-[0-9]{2}"'
fe="$P/frontend"; S_repo="$fe/../backend"
ok "a session inside frontend (main or unit folder) finds backend as <main>/../backend" 'git -C "$S_repo" rev-parse --verify -q refs/heads/main && [ ! -d "$fe/backend" ]'
build syncrec --no-milestones
fe="$P/frontend"; open_ backend t-discount; open_ frontend m6; open_ frontend t-discount
printf '# HANDOFF\n\n## Session log\n- 2026-09-27 10:00 fact: t-discount after: backend t-discount\n' > "$fe/.worktrees/m6/HANDOFF.md"
commit_ "$fe/.worktrees/m6" "docs: handoff 2026-09-27" HANDOFF.md; land_ "$fe/.worktrees/m6" m6; (cd "$fe" && clean_ frontend m6)
t="$fe/.worktrees/t-discount"
ok "before Sync the task folder has no record" '! grep -q "t-discount after:" "$t/HANDOFF.md" 2>/dev/null'
git -C "$t" merge -q --no-edit origin/main
ok "after Sync it has one, and the rerun check stops the land (backend t-discount not landed)" 'grep -q "t-discount after: backend t-discount" "$t/HANDOFF.md" && ! landed backend t-discount'

echo; echo "passed $P_, failed $F_"; [ "$F_" -eq 0 ]
