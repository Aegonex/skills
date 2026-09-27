# Repos: a folder that holds several repos

Read this when a skill's `worktree list` fails with `not a git repository`; its section for that skill replaces the step. The
calling skill's rules hold: Language, one command per call and line, `git -C "<absolute folder>"`, exit codes from the tool
result. Nothing is ever written in `<P>`: no `git init`, `clone`, file, folder or `.worktrees`.
## 1. Find the repos
`<P>` is the folder the session opened in (the harness's working folder, else the first `pwd`), kept all session, never the
shell's folder after a `cd`. Run `ls -pL "<P>"` (PowerShell `Get-ChildItem -Directory -Name -LiteralPath "<P>"`, cmd `dir /b
/ad "<P>"`), then per folder `<d>` not starting with `.`, one call each: `git -C "<P>/<d>" rev-parse --show-prefix
--git-dir`. An empty line, then `.git`: `<d>` is a repo `<r>`. Else (exit 128, a subfolder or a linked worktree of a repo):
skipped. Another fatal error: the row `<d>: not read: <first error line>`. No other git command names `<P>` itself.
No repo: the whole reply is `<P> is not a git repo and holds none: create or clone one yourself, then run aegonex-init in
it` / `<P> ไม่ใช่ git repo และไม่มี repo ข้างใน: สร้างหรือ clone เอง แล้วเรียก aegonex-init ในนั้น`. More than 6: `<P> holds
<n> repos; open the session in one of them` / `<P> มี <n> repo: เปิด session ใน repo ใด repo หนึ่ง`. Both write nothing.
Each repo is a v0.4 project with `<main>` = `<P>/<r>`: its own Base, Remote, `## Commands`, `.worktrees/` and AGENTS.md
rules; each skill runs its steps per repo. Brief rows and reply lines lead with `<r>: `; paths read `<r>/.worktrees/<u>`.
## 2. Records
A task across repos keeps one `t-<slug>` in each (`-2` where an old pull request holds it; a record names each repo's own
unit); a milestone is each repo's own next `m<n>`. The provider lands first: the repo whose API the others call (for a
removal, the caller); the agent's call, shown as a Decision `(agent's call)` the user may change. A record lives only in the
consumer, only in a repo whose AGENTS.md has the Repos heading, and only a session opened in `<P>` writes it: `after: <r>
<v>`, `<v>` = `m<k>` or `t-<slug>`, several as `after: backend m3, auth t-token`. A milestone's sits on its ROADMAP line
before `done when:` (`- [ ] M5 — cart page · after: backend m3 · done when: ...`), in its `docs: plan M<n>` commit; a task's
is a HANDOFF line `t-<slug> after: <r> <v>`, written only while the provider's `aegonex/<v>` exists. Never a cycle. Land
order: a unit after every unit its record names, else folder-name order. In such a repo milestone numbers never change.
## 3. The landed check
Read only; `<S>` = `<P>/<r>` (from inside one repo, `<main>/../<r>`), `<SB>` = `<remote>/<Base>` from `<S>/AGENTS.md` (no
remote: `<Base>`). `git -C "<S>" rev-parse --verify -q refs/heads/aegonex/<v>` printing a sha: not landed; for a task, no sha
is landed. For `m<k>` then `git -C "<S>" grep -q -E "^- \[x\] M<k> .* closed [0-9]{4}-[0-9]{2}-[0-9]{2}" <SB> -- ROADMAP.md`:
exit 0 is landed. No `<S>`, a git error or a cycle: stop, `<u>: after: <r> <v> cannot be checked: <reason>` / `<u>: ตรวจ
after: <r> <v> ไม่ได้: <reason>`. Nothing in `<S>` is fetched, switched, opened or written; besides these, only its AGENTS.md
is read. Callers rerun it before **Land** when Sync merged anything (it may bring a record in).
## 4. Sessions
One session per repo at a time; a parent session holds each repo it opens a unit in. A `worktree add` refusal (`already
exists`, `already checked out`): another session holds that unit; quote it and stop, never retry under another name.
## 5. Init in the parent
Facts per repo: `worktree list`, `branch --show-current` and status of `<main>`, its AGENTS.md and ROADMAP.md; init's steps
1-4 in full only for a repo with a unit folder, a main folder not clean or off its Base, or the first step's repo; setup is
due by init's step 2, where a missing `## Repos (aegonex 0.5)` alone adds only that section (Setup: `<r>: Repos section`).
Brief: title `**<P's name> · <n> repos**` / `**<P's name> · <n> repo**`; a row per repo, labelled `<r>`: its Current work,
else `no plan yet` / `ยังไม่มีแผน` or `not set up` / `ยังไม่ได้ตั้งค่า`, plus ` · lands after <r2> <v>` / ` · land หลัง <r2>
<v>` while its record has not landed, plus its first other row in a few words and `+<n> more` / `+อีก <n>`; then the Setup,
Will move and Read by mistake rows, their Detail led by `<r>: `. At most 25 lines.
First step: init's rules 1-7 over every repo; the lowest rule wins, but a wait (rule 3 while online, a consumer's rule 6
below) ranks after every other repo's rules; a tie goes by land order; rule 7 counts once, `run aegonex-plan` (it asks which
repos). A consumer whose record has not landed reads rule 6 as `when <r2> <v> has landed, run aegonex-done (a task may start
meanwhile)` / `เมื่อ <r2> <v> land แล้ว เรียก aegonex-done (ระหว่างนี้เริ่มงานย่อย t- ได้)`. A focus naming a repo picks it;
one spanning repos (an API and its caller) is a cross-repo task. One question, as init's; a Base or Remote to ask names its
repo (`Which branch is Base in <r>?` / `Base ของ <r> คือ branch ไหน?`); the first such repo asks.
Go: setup runs in every repo where it is due (init's setup plus section 11, or section 11 alone) whose main folder is clean
(apart from what setup commits) and on its Base, or will be after the move, and needs no question: each named in a Setup row,
one `chore: aegonex setup` commit per main folder. Move, update and open run only in the first step's repos, in land order.
Reply at most 2 lines: `**Opened:** backend/.worktrees/t-discount, frontend/.worktrees/t-discount` (every folder the first
step works in, even one that existed), then one line of clauses led by `<r>: `. Then Leader mode, section 7.
## 6. Plan in the parent
The repos a feature changes and which lands first come from the user's own words (never words they did not write), else the
agent's call: an `(agent's call)` Decisions line in each touched ROADMAP.md (plan's `My call` row). Stops, a line each led by
`<r>: `, nothing written: a touched repo's plan stop; no Repos heading, `<r>: run aegonex-init <r> first` / `<r>: เรียก
aegonex-init <r> ก่อน`; a cycle; an open folder whose status lists ROADMAP.md, `<r>: ROADMAP.md in .worktrees/m<n> has
changes not committed; another session may be writing it` / `<r>: ROADMAP.md ใน .worktrees/m<n> มีการแก้ที่ยังไม่ commit:
อาจมี session อื่นเขียนอยู่`. One milestone per touched repo: an open, unticked one gets the feature as a later milestone
line, else a new `m<n>`; each step belongs to one repo; at most 7 steps per milestone, 7 questions in all; consumer lines
carry the record. The brief is plan's, its title naming each ROADMAP.md it goes to, `Done when:` per repo, a `Repo` / `repo`
column in the steps table and a row `Lands after` / `land หลัง` (`frontend M5 after backend M3`). Go: plan's go per repo, in
land order; one reply of at most 3 lines naming each folder and commit, then step 1 as `<r> <step> · done when: ...`.
## 7. Leader mode across repos
A parent request is one ROADMAP step (one repo) or one cross-repo task. That task opens (init's go or the leader's start) in
each repo in land order with its **Open**; a repo without the Repos heading stops it first (section 6's line). Before
dispatch, note writes, in the user's language, each repo's `t-<slug> done when:`, each consumer's record and, unless the user
named the order, a decision in each repo that backend lands first, ending `(agent's call)`; its reply lines open the report.
A part never spans repos: each repo is at least one part, 2-5 parts in all, dispatched at once in `<r>/.worktrees/<u>--p<k>`;
more: split the task by repo, providers first. Review lines lead with the repo (`frontend p1: PASS: ...`); a part integrates
into its repo's `aegonex/<u>`. When every repo's last part is integrated, folders whose status lists HANDOFF.md end the
report with one line, `run aegonex-exit first: HANDOFF.md in <r>/.worktrees/<u>, ... has notes not saved`; else one land
question in land order, `Land? backend, then frontend: push aegonex/t-discount to main, remove backend/.worktrees/t-discount,
frontend/.worktrees/t-discount and their aegonex/t-discount: Not yet / go` (Thai `ยังไม่ land`; each Base named when they
differ). Its go, per repo in order: the landed check of its records, always run (a provider cleaned up on this go passes it);
Sync as `aegonex-done` step 2 says; the check again if Sync merged anything; **Land**; **Clean up**. A repo that does not
finish Clean up (a stop, a pull request, a refusal) stops the rest. Reply: a line per repo in the land go's form, paths
`<r>/.worktrees/<u>` (landed, the pull request with the folder kept, the stop, or `not reached` / `ยังไม่ได้ทำ`), then
`Next:`. Asked to, the leader lands only the repos whose parts are all integrated; a consumer still needs its check.
## 8. Note
Note's steps 1-6 in each repo concerned (never `<main>`; no unit folder: Not saved there); a record: a `fact` line in each
consumer. The reply starts `Noted (<kind>) in backend, frontend: <text>` / `จดแล้ว (<ประเภท>) ใน backend, frontend: <text>`.
## 9. Exit
Exit's steps 1-8 run for each repo the session worked in (after a compaction: those whose unit folders list files or whose
HANDOFF.md has a Session log), with one brief whose rows and action line name each repo (`backend: HANDOFF.md, ROADMAP.md ·
frontend: HANDOFF.md`), a commit per repo, the reply `backend a1b2c3d · frontend e4f5a6b`, then section 7's land question
when every part is integrated. Push what I have: in land order, the landed check run before the brief, so a consumer not
landed reads `committed, not pushed: lands after <r> <v>` / `commit แล้ว ยังไม่ push: รอ <r> <v>` in the action line and
Stopped at; the first refusal stops the rest; one Remove / Keep question for every landed folder, Keep first; a provider task
that a sibling's record names is kept, not offered.
## 10. Done
The unit is the one named (`backend m3`, or a name one repo has); a name several repos have: the first in land order whose
records have landed, else one question naming `<r> <u>`. A merged pull request naming none: the one unit, across repos, with
a `<remote>/aegonex/<u>` copy (several: the question). After a provider's Clean up, `Next` names the consumer's next step
(`aegonex-done for frontend m5` once its steps are ticked). Step 8 keeps an unclosed provider task a record names.
## 11. The Repos section
Setup appends `assets/AGENTS-repos.md` to a repo's AGENTS.md when that heading is missing, in its `chore: aegonex setup`.
