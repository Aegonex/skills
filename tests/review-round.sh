########################################################################
# v0.4 review round: one scenario per finding, each with the fixed recipe (sourced by lifecycle.sh)
on_base() { [ "$(git -C "$M" branch --show-current)" = main ]; }                       # done step 1 / Clean up 2 test

say "21 move from a v0.3 branch; exit lands unfinished with Sync of both refs; setup carried"
mkrepo mv; printf '# app v0.3\n## Rules\n- user rule\n' > "$M/AGENTS.md"; commit_ "$M" "docs: agents" AGENTS.md; git -C "$M" push -q origin main
git -C "$M" switch -q -c fix/db; printf 'db\n' > "$M/db.js"; commit_ "$M" "feat: db" db.js
git -C "$M" switch -q main; setup_; S_SHA=$(git -C "$M" rev-parse main)
open_ t-db fix/db; U=$M/.worktrees/t-db; git -C "$U" merge -q --no-edit main; printf 'more\n' >> "$U/db.js"   # move step 7 merges Base
ok "unit from <b> carries the setup commit and the sections (move step 7)" 'git -C "$M" merge-base --is-ancestor main aegonex/t-db && grep -q "Working mode" "$U/AGENTS.md"'
commit_ "$U" "wip: db" db.js                                                               # exit step 9.1: commit first
ok "exit 9.2 Sync (done step 2): local Base is only setup, merged" 'base_ok "$U" && sync_ "$U" && git -C "$M" merge-base --is-ancestor main aegonex/t-db'
ok "scan clean, land" '[ -z "$(scan_ "$U" t-db)" ] && [ "$(land_ "$U" t-db)" = landed ]'
ok "Remove = Clean up: ff works, setup commit kept, sections in <main>" 'clean_ "$U" t-db && git -C "$M" merge-base --is-ancestor $S_SHA main && grep -q "Working mode" "$M/AGENTS.md"'

say "21b the reset guard: a squashed PR that did not carry the setup never drops it"
mkrepo guard; protect; setup_
open_ t-g origin/main; U=$M/.worktrees/t-g; printf 'g\n' > "$U/g.js"; commit_ "$U" "feat: g" g.js   # e.g. an old unit from the remote
git -C "$U" commit -q --allow-empty -m "chore: close t-g"; land_ "$U" t-g >/dev/null
platform_merge aegonex/t-g squash; git -C "$M" fetch -q origin main
ok "pushed check equal" '[ "$(pushed_check t-g)" = equal ]'
ok "Update stops: online Base lacks the sections, setup stays in <main>" '! clean_ "$U" t-g -D && grep -q "Working mode" "$M/AGENTS.md" && [ -d "$U" ]'

say "22 <main> switched by the user to their own branch: nothing moves"
mkrepo sw; protect; setup_
open_ m1; U=$M/.worktrees/m1; printf 'q\n' > "$U/q.js"; commit_ "$U" "feat: q" q.js; sync_ "$U"
git -C "$U" commit -q --allow-empty -m "chore: close m1"; land_ "$U" m1 >/dev/null
git -C "$M" switch -q -c my-idea; printf 'mine\n' > "$M/mine.js"; commit_ "$M" "my own work" mine.js; MINE=$(git -C "$M" rev-parse HEAD)
platform_merge aegonex/m1 squash; git -C "$M" fetch -q origin main
ok "done step 1 stops: the main folder is not on Base" '! on_base'
ok "Update refuses too; my-idea keeps its commit and file" '! update_main && [ "$(git -C "$M" rev-parse my-idea)" = "$MINE" ] && [ -f "$M/mine.js" ]'
git -C "$M" switch -q main
ok "an empty log never qualifies for the reset" 'git -C "$M" reset -q --keep origin/main && [ -z "$(git -C "$M" log --format=%s origin/main..main)" ]'

say "23 a reused task name after a squashed PR whose branch the host kept"
mkrepo reuse; protect; setup_
open_ t-typo; U=$M/.worktrees/t-typo; printf 'hullo\n' > "$U/README.md"; commit_ "$U" "fix: typo" README.md
git -C "$U" commit -q --allow-empty -m "chore: close t-typo"; land_ "$U" t-typo >/dev/null
platform_merge aegonex/t-typo squash; git -C "$M" fetch -q origin main; clean_ "$U" t-typo -D
N=$(free_task t-typo)
ok "init names the new task t-typo-2" '[ "$N" = t-typo-2 ]'
open_ "$N"; U=$M/.worktrees/$N; printf 'hello there\n' > "$U/README.md"; commit_ "$U" "fix: typo 2" README.md
sync_ "$U"; git -C "$U" commit -q --allow-empty -m "chore: close $N"
ok "not online before landing" '! online_ "$U" "$N"'
ok "lands through a fresh pull request" '[ "$(land_ "$U" "$N")" = pr ] && online_ "$U" "$N"'
open_ t-old; git -C "$M" update-ref refs/remotes/origin/aegonex/t-old "$(git -C "$M" rev-parse origin/aegonex/t-typo)"
ok "a stale online ref with another hash is not online" '! online_ "$M/.worktrees/t-old" t-old'
open_ m7; U=$M/.worktrees/m7; git -C "$O" update-ref refs/heads/aegonex/m7 "$(git -C "$M" rev-parse origin/aegonex/t-typo)"; git -C "$M" fetch -q origin
ok "plan/init test: a milestone whose online ref exists is caught before the go" 'git -C "$M" rev-parse --verify -q refs/remotes/origin/aegonex/m7'
printf 'm\n' > "$U/m.js"; commit_ "$U" "feat: m" m.js; git -C "$U" commit -q --allow-empty -m "chore: close m7"
ok "had it gone on: the branch push is refused and stops (quoted)" '[ "$(land_ "$U" m7)" = stop:branch-push ] && grep -q "rejected" "$RUN/push2.out"'

say "24 harness folder made before setup, adopted from Base, protected squash, next init update"
mkrepo harn; protect; H="$D/h1"; git -C "$M" worktree add -q -b claude/h1 "$H" main
setup_
ok "adoption guard: harness is on a branch outside aegonex/*" '! git -C "$H" branch --show-current | grep -q "^aegonex/"'
git -C "$H" worktree prune; git -C "$H" switch -q -c aegonex/t-h main
ok "adopted unit carries the setup commit" 'git -C "$M" merge-base --is-ancestor main aegonex/t-h'
printf 'h\n' > "$H/h.js"; commit_ "$H" "feat: h" h.js; git -C "$H" commit -q --allow-empty -m "chore: close t-h"; land_ "$H" t-h >/dev/null
platform_merge aegonex/t-h squash; git -C "$M" fetch -q origin main
git -C "$H" switch -q --detach; git -C "$H" branch -D aegonex/t-h >/dev/null
ok "Main folder behind fires (log main..origin/main)" '[ -n "$(git -C "$M" log --oneline -1 main..origin/main)" ]'
ok "init update = Update: guarded reset, h.js in <main>, sections kept" 'update_main && [ -f "$M/h.js" ] && grep -q "Working mode" "$M/AGENTS.md"'

say "25 empty remote: the scan covers the whole branch"
D="$RUN/empty"; mkdir -p "$D"; O="$D/origin.git"; M="$D/app"; git init -q --bare -b main "$O"; git init -q -b main "$M"; git -C "$M" remote add origin "$O"
printf 'x\n' > "$M/x.js"; setup_; git -C "$M" add -- x.js; git -C "$M" commit -q -m "chore: aegonex setup" -- x.js
open_ t-k; U=$M/.worktrees/t-k; printf 'const k = "sk-proj-abcdefghijklmnopqrstuvwxyz";\n' > "$U/k.js"; commit_ "$U" "feat: k" k.js
ok "no <remote>/<Base>: range is aegonex/<u>; the key is found" 'scan_ "$U" t-k | grep -q sk-proj'
ok "Sync: local Base is only setup lines, so it is not a stop" 'base_ok "$U"'

say "26 exit 'push what I have' with an edit to a file Base changed: commit, then Sync"
mkrepo ex9; setup_; git -C "$M" push -q origin main
open_ t-w; U=$M/.worktrees/t-w; printf 'mine\n' >> "$U/a.js"
S="$D/oth"; command git clone -q "$O" "$S"; printf 'theirs\n' > "$S/a.js"; git -C "$S" add a.js; git -C "$S" commit -qm other; git -C "$S" push -q origin main
commit_ "$U" "wip: w" a.js
ok "Sync conflicts after the commit (a merge that started)" '! sync_ "$U" && git -C "$U" rev-parse -q --verify MERGE_HEAD'
ok "merge --abort works; the committed edit is intact; nothing landed" 'git -C "$U" merge --abort && grep -q mine "$U/a.js" && ! git -C "$M" ls-remote --exit-code origin refs/heads/aegonex/t-w'

say "27 a Thai file name: status read with core.quotePath=false goes back to git"
mkrepo thai; setup_; printf 'x\n' > "$M/บันทึก.md"
P=$(status_ "$M" | sed -n 's/^?? //p')
ok "status prints the real name, add -N accepts it" '[ "$P" = "บันทึก.md" ] && git -C "$M" add -N -- "$P"'
ok "the default status would have quoted it" 'git -C "$M" status --short | grep -q "\\\\340"'

say "28 a .env made while the pull request waits is named before removal"
mkrepo envw; protect; setup_
open_ t-e; U=$M/.worktrees/t-e; printf 'q\n' > "$U/q.js"; commit_ "$U" "feat: q" q.js; git -C "$U" commit -q --allow-empty -m "chore: close t-e"; land_ "$U" t-e >/dev/null
printf 'DB_PASSWORD=local\n' > "$U/.env"
ok "waiting brief's Goes with the folder row lists .env" 'git -C "$U" -c core.quotePath=false status --short --ignored | grep -q "^!! .env"'

say "29 an unpushed commit on local Base is not carried by Sync"
mkrepo priv; setup_; git -C "$M" push -q origin main
open_ t-a; U=$M/.worktrees/t-a; printf 'a\n' > "$U/x.js"; commit_ "$U" "feat: x" x.js
printf 'exp\n' > "$M/exp.js"; commit_ "$M" "wip: my private experiment" exp.js
sync_ "$U" >/dev/null; rc=$?
ok "Sync stops (rc 2) and names the commit" '[ $rc = 2 ] && git -C "$M" log --format=%s origin/main..main | grep -q "private experiment"'
ok "the unit does not contain it" '! git -C "$U" merge-base --is-ancestor main HEAD'

say "30 host deleted the PR branch and a pruning fetch removed its copy"
mkrepo prune; protect; setup_
open_ m1; U=$M/.worktrees/m1; printf 'q\n' > "$U/q.js"; commit_ "$U" "feat: q" q.js; sync_ "$U"; git -C "$U" commit -q --allow-empty -m "chore: close m1"; land_ "$U" m1 >/dev/null
platform_merge aegonex/m1 squash delete; git -C "$M" fetch -q --prune origin
ok "closed, not online, not landed by ancestry: route 3 (brief offers 'say merged')" 'closed_ "$U" m1 && ! online_ "$U" m1 && ! landed_ m1'
ok "user says merged: the pushed check reads gone, not different" '[ "$(pushed_check m1)" = gone ]'

say "31 go order: update before setup on a stale <main>"
mkrepo stale; S="$D/oth"; command git clone -q "$O" "$S"; printf 'b\n' > "$S/b.js"; git -C "$S" add b.js; git -C "$S" commit -qm other; git -C "$S" push -q origin main; git -C "$M" fetch -q origin
ok "update first fast-forwards" 'update_main && [ -f "$M/b.js" ]'
setup_
ok "setup on top; <main> not behind" '[ -z "$(git -C "$M" log --oneline -1 main..origin/main)" ]'

say "32 while m2 waits for its PR, a task session keeps HANDOFF in its own folder"
mkrepo wait; protect; setup_
open_ m2; U=$M/.worktrees/m2; printf 'x\n' > "$U/x.js"; commit_ "$U" "feat: x" x.js; git -C "$U" commit -q --allow-empty -m "chore: close m2"; land_ "$U" m2 >/dev/null
open_ t-fix; UT=$M/.worktrees/t-fix
ok "state folder skips the closed m2" '[ -z "$(state_folder)" ]'
printf '# HANDOFF t-fix\n' > "$UT/HANDOFF.md"; commit_ "$UT" "docs: handoff 2026-09-26" HANDOFF.md
ok "m2 still closed and equal to its online copy" 'closed_ "$U" m2 && [ "$(pushed_check m2)" = equal ]'

say "33 a harness folder already holding t-a is not adopted again"
mkrepo adopt; setup_; H="$D/harness"; git -C "$M" worktree add -q -b claude/h "$H" main
git -C "$H" switch -q -c aegonex/t-a main; printf 'edit\n' >> "$H/a.js"
ok "guard: harness is on aegonex/*, so m1 opens under .worktrees" 'git -C "$H" branch --show-current | grep -q "^aegonex/" && open_ m1 && [ -d "$M/.worktrees/m1" ]'
ok "t-a keeps its edit and its folder" '[ "$(git -C "$H" branch --show-current)" = aegonex/t-a ] && [ -n "$(status_ "$H")" ]'

say "34 closed, landed, cleanup stopped earlier: route 3 offers only Clean up"
mkrepo relnd; setup_; open_ t-s; U=$M/.worktrees/t-s; printf 's\n' > "$U/s.js"; commit_ "$U" "feat: s" s.js; git -C "$U" commit -q --allow-empty -m "chore: close t-s"
land_ "$U" t-s >/dev/null; printf 'stray\n' > "$U/stray.txt"
ok "cleanup stops on the stray file" '! clean_ "$U" t-s'
rm -f "${U:?}/stray.txt"
ok "rerun: landed by ancestry, so Clean up only (no second push)" 'landed_ t-s && clean_ "$U" t-s'

say "35 a ruleset rejection (GH013 on remote: lines) takes the pull request path"
mkrepo rules; setup_; git -C "$M" push -q origin main
printf '#!/bin/sh\nwhile read o n ref; do [ "$ref" = refs/heads/main ] && [ -z "$ALLOW" ] && { echo "error: GH013: Repository rule violations found for refs/heads/main."; exit 1; }; done; exit 0\n' > "$O/hooks/pre-receive"; chmod +x "$O/hooks/pre-receive"
open_ t-r; U=$M/.worktrees/t-r; printf 'r\n' > "$U/r.js"; commit_ "$U" "feat: r" r.js; git -C "$U" commit -q --allow-empty -m "chore: close t-r"
ok "classified as protected (the reason is on a remote: line)" '[ "$(land_ "$U" t-r)" = pr ] && grep -q "^remote:.*GH013" "$RUN/push.out"'

say "36 a part branch left over stops done"
mkrepo parts; setup_; open_ m1; U=$M/.worktrees/m1
git -C "$U" worktree add -q -b aegonex/m1--p1 "$M/.worktrees/m1--p1" aegonex/m1
ok "done step 1: parts not integrated" '[ -n "$(git -C "$M" branch --list "aegonex/m1--p*")" ]'
