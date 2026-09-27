# Testing a skill

Skills are tested like code: watch an agent fail without the skill, write
the skill against those failures, watch it pass, close the loopholes.

## Fixtures

`tests/fixtures/make-fixtures.sh <dir>` builds the two roots; the other
builders take `<dir> <src-dir>` and copy from `stale-app` or `fresh-app`.
Copy a fixture per run; agents mutate them.

| Fixture | Builder | State |
|---|---|---|
| `stale-app` | `make-fixtures.sh` | state files present; HANDOFF written on `feat/auth-refresh` with `HEAD:`, then a handoff commit touching `HANDOFF.md` and `src/`, then a drift commit; checked out on `fix/db-race` with a dirty `src/db.ts` |
| `fresh-app` | `make-fixtures.sh` | no state files |
| `session-end-app` | `make-exit-fixture.sh` | stale-app after a day of work: a committed test, an uncommitted half-done refresh path, the open step already marked `(in progress)` |
| `noinit-app` | `make-noinit-fixture.sh` | fresh-app with uncommitted work and no state files |
| `planned-app` | `make-planned-fixture.sh` | M2 fully ticked, M3 has no steps: init must point to `aegonex-plan` |
| `closed-app` | `make-closed-fixture.sh` | M2 steps ticked, every `done when` a runnable `bash tests/check-*.sh`, two docs on the `docs:` line, one untracked file under `docs/scratch/` |
| `closed-app-failing` | `make-closed-fixture.sh … --failing` | same, with one check that fails |
| `sessionlog-app` | `make-sessionlog-fixture.sh` | HANDOFF with a `## Session log` left by a session that never ran exit, and a `HEAD:` sha that no longer exists |

`tests/fixtures/make-v04-fixture.sh <fixture> <unit> [--protected]` turns a
built fixture into a v0.4 one in place, with the spec's own recipes: a bare
`<fixture>.origin.git` beside it, the setup commit on `main`, and the
fixture's branch and uncommitted files moved into `.worktrees/<unit>`.
`--protected` adds a pre-receive hook that refuses pushes to `main` the way
a host's branch protection does. It refuses a folder that is not a fixture
repo of its own or already has a remote.

## Git lab (v0.4)

`bash tests/lifecycle.sh` walks every git command the v0.4 skills and
AGENTS.md name, with the placeholders filled in, on bare repos as remotes,
with a `gh` stub on `PATH` (no network): setup, plan, a two-part lead,
tasks, exit, done, the protected path with squash and merge commits, Keep
and Remove, harness adoption and the stop rows. It sources
`tests/review-round.sh`, which replays each review finding with its fixed
recipe. It exits non-zero on any FAIL.

The run folder is `$AEGONEX_RUN`, else a new folder under `$TMPDIR`. The
script stops before any git command when that folder is inside a git repo
and sets `GIT_CEILING_DIRECTORIES` to it. Without that guard, an empty run
folder (macOS `mktemp -d` fails in some sandboxes) sends every scenario
into the repository you ran it from: that happened once, on this repo.

## Git lab (v0.5)

`bash tests/multi-repo.sh` does the same for a parent folder holding
several repos, built by `tests/fixtures/make-multi-fixture.sh <dir>
[--protected <r>] [--repos <n>] [--ticked] [--no-milestones]
[--no-repos-section] [--git-init-parent]`: `<dir>/shop` holds backend
(`m3` open, 2 of 3 steps ticked), frontend (`m5` open, all ticked,
`after: backend m3`), each ticked step's code committed in its unit
folder, admin (not set up), `docs/` and `notes.txt`, with
bare remotes in `<dir>/remotes` whose hooks log each push to
`<dir>/push-order.log`. It checks finding the repos (a subfolder and a
linked worktree are not repo roots, a plain folder exits 128), the
landed check before and after a milestone's close push and after a
squash-merged pull request, `M3` against `M30`, a cross-repo task whose
provider push is refused (the consumer stays untouched, then lands
second), a unit opened before the Repos-section commit (done's 7.4.2
keeps that commit and goes on with `-D`; the next unit lands it), the
nested-repo guard, a closed line saved with CRLF, a frontend session
finding backend as `<main>/../backend`, a record brought in by Sync that
stops the rerun check, and that nothing is written in the parent. 37
checks. Same run-folder guard as `lifecycle.sh`.

## Method

1. RED: give a cheap model (Sonnet) the fixture path and the user's message
   only. Record what it reads, runs, writes and replies. For a skill that
   already exists, RED runs the previous version (`git archive HEAD` into a
   scratch dir).
2. GREEN: same runs, with "the user invoked <skill>; read SKILL.md and
   follow it". The prompt asks for the exact reply in `brief.md` and every
   command, read and write in `trace.md` (a harness may refuse a subagent
   write to a file named `report.md`).
   `tests/judge.sh <kind> <brief-file> <fixture> [th|en]` checks the brief's
   shape (a bold title first, one table outside any code block, no row that
   says none, 0 or -, no emoji, no HEAD sha, the action line, `**go**` once
   and on the last line, at most 25 lines; with `th|en`, the language: at
   least half the lines in Thai, or none) and prints disk facts (every
   worktree, the `aegonex/*` branches, the online refs); the scenario's own
   assertions run on those facts. v0.4 kinds: `done-wait` (the reply while
   a pull request waits), `after-go` (the report after a go: at most 3
   lines, no table, no question) and `keep-ask` (the Remove / Keep question
   after unfinished work landed: at most 4 lines, **remove** once on the
   last line) and `init-go` (init's reply after go: the `**Opened:**` line,
   then one line of what the go did, no table or question in those two,
   then the step's report). `tests/samples/` holds one passing reply per
   v0.4 kind.
3. REFACTOR: every deviation becomes a red flag, a rationalization row or a
   required slot in the template, then the affected scenarios run again.

Four scenario shapes need a trick:
- v0.4 scenarios run in turns (the brief, then `go`, sometimes a third
  message). Each turn is a fresh agent that reads the earlier turns'
  brief and trace as its memory. Before each later turn a snapshot records
  every ref, worktree, status, diff and origin ref; the brief turn must
  leave it unchanged. Every command starts with `cd "<session folder>" && `
  so an agent whose shell starts elsewhere never touches another repo.
  From v0.5.1 the shell also keeps no `cd` between calls (a bare `cd`
  changes nothing), a command that starts with its own `cd "<absolute
  folder>" && ` takes no prefix, and the trace records each command
  without the prefix.
- Work the user asks for directly (a typo, a two-module change) names no
  skill: the prompt gives the project's `AGENTS.md` as the loaded
  instruction file and lists the skills, and the checks read the Working
  mode and Leader mode sections as the contract.
- `aegonex-plan` asks questions one at a time, and a subagent cannot wait for
  a user. The prompt scripts the user's answers in order and tells the agent
  to write each question it would ask into its trace before taking the next
  answer. The judge counts the questions.
- `aegonex-note` must trigger from its description alone. The prompt lists
  all five skills with their descriptions and paths, describes a situation
  (an approach that just failed) and a user message that names no skill.
  Pass means the agent read the note skill and wrote the line before
  continuing.

## Results that shaped v0.1 (2026-09-02)

Without the skills, agents opened source files before the user said go,
missed commits newer than the handoff, closed sessions by committing on
their own (3/3) and wrote fragments of a planted secret into HANDOFF.md
(2/3).

## Results that shaped v0.2 (2026-09-02)

- v0.1 init wrote four files into a fresh repo before go and its anchor grep
  matched its own AGENTS.md template. v0.2 init creates nothing before go and
  only `AGENTS.md` and `CLAUDE.md` after it.
- Without a plan skill, the agent asked nine questions (three of them
  approval questions), wrote a 1000-line implementation plan and a spec
  under `docs/` instead of `ROADMAP.md`, and committed both on its own.
- Without a note skill, a decision stated mid-session went into ROADMAP's
  Decisions after the agent had implemented the whole feature; nothing
  reached HANDOFF.md.
- v0.1 exit, in one run, ran `npx vitest run` during the close and installed
  `node_modules`; the agent reported its own violation. v0.2 names that
  rationalization.
- Without a done skill, the agent ran the milestone's checks (good), then
  invoked exit on its own, rewrote HANDOFF.md and lost its dead ends, never
  collapsed the milestone, and refused to structure the deletions.

## Results that shaped v0.3 (2026-09-26)

Eight scenarios (init stale, fresh and session log; plan; exit; done passing
and failing; note), one run each, v0.2 against v0.3.

- v0.2 briefs failed 51 of 83 shape checks (no bold title, no table, the
  HEAD sha, no bold **go** on the last line) and 4 of 8 language checks
  (English labels for a Thai user). Its exit wrote HANDOFF.md in English
  for a Thai user.
- v0.3 passed 83/83 shape and 8/8 language checks, and 52 of 54 behaviour
  checks. Both misses were exit copying the example date in its SKILL.md
  into HANDOFF.md and the commit message. Exit, done and plan now take today
  from `date +%F` and their examples say `<today>`; the rerun passed 25/25
  (exit) and 19/19 (done failing).
- done, on a failing check, put a behaviour in backticks as if it were a
  command; its row template now says which is which.

## Results that shaped v0.4 (2026-09-27)

The lab (`tests/lifecycle.sh`) passed 130/130 and the judge regression
stayed green before any agent ran. Eleven agent scenarios (V1-V11 in
`docs/design.md`), Sonnet, one run each, turn by turn.

Round 1: 2 of 11 passed, 36 of 61 behaviour checks. Harness faults first:
the fixture staged moved files (`apply --3way` implies `--index`), the
closed fixtures had no test runner behind `npm test`, the forbidden-command
grep matched prose, and the user's own memory (reply in Thai) leaked into
an English scenario. Then the skill faults:
- init fell back to the current branch for Base, so the go stalled on
  `fix/db-race`, and it moved that work into `m2`. Base now falls back to
  `main` / `master` and then asks; moved work goes to `t-<slug>` from the
  branch name.
- plan's go told the agent to start step 1; it built two steps, then
  reverted them. The go now opens, commits ROADMAP.md, replies in three
  lines and stops.
- exit wrote HANDOFF.md in English for a Thai user because the old file
  was English (2 of 3 exit runs). The file follows the reply's language.
- done stopped at the first failing check and hid the rest; with the
  runner missing and the install line `none`, it had no first step. It now
  runs every check and names a by-hand install step.
- Agents chained commands with `&&` after the harness's `cd` prefix; the
  prompt now allows one command after it, and AGENTS.md says one command
  per call.

Round 2, after those fixes: 6 of 11 passed (V2, V5, V6, V8, V9, V10), 47
of 59 behaviour checks. The deterministic checks had to be fixed first:
done may merge on its unit branch before the go (Sync), so the "nothing
changed" gate became "only merge commits on `aegonex/<u>`", and the chain
check now reads only the command span of each trace line
(`chains.py`), not quoted script output. The skill faults left:
- init (V1): the moved unit branched from `fix/db-race` lacked the setup
  commit, so the folder the user was sent to had no v0.4 sections; the go
  reply grew to four lines and diagnosed a failed `npm install` with a
  `sudo` fix. The move now merges Base into the new unit, the go part is
  two lines, and a failed install is quoted, not diagnosed.
- AGENTS.md (V3, V4, V8, V9): agents chained read-only commands
  (`pwd && ls`, `; echo $?`), reviewed after committing, and ended a
  finished task without the land question, so a bare go landed a reply
  that had not named it. Commands, Review and Go now say each of these.
- exit (V11): with a task as the state folder while `m2` waited for its
  pull request, HANDOFF.md dropped the waiting milestone and the day's
  decision. Its Notes now end with the waiting line and carry the
  decision.
- done (V7, V10): after "the PR is merged" it asked a second question
  although the close go had named the removal, and it guessed an
  `<owner>/<repo>` for `gh` on a path remote; a go on a cannot-close
  brief had no procedure. Clean up now runs on the merged message, `gh`
  and the compare link need a host URL, and that go runs the fix as one
  reviewed part.

Round 3, after fix round 2: 8 of 11 passed (V2, V4, V5, V6, V8, V9, V10,
V11), 49 of 55 behaviour checks, every deterministic check green. What
round 2 broke now holds: the moved unit carries the setup commit, the
init go reply is two lines and quotes a failed install, a finished task
asks its land question with `Not yet` first, the exit HANDOFF of a task
names the milestone waiting for its pull request, done opens no guessed
pull request on a path remote and cleans up at once on "merged", and a
go on a cannot-close brief runs the fix as one reviewed part. Left:
- AGENTS.md (V3): with no subagent tool the agent made the two-module
  request one part, and its own review skipped `diff HEAD` and gave no
  PASS/FAIL; Size now says parts are judged by files, never by tools.
- init (V1): one plain `git worktree list` and a `cd ... && npm install`
  in the go; Open now runs the install after a `cd` of its own.
- done (V7): the retro rule went into the main folder's `AGENTS.md`,
  since the skill never named the folder; it now names `<f>`.
- plan (V2, passed): five questions where two were needed, as in round 2;
  the harness also handed answers out by position, so skipping question
  1 was punished. Answers are now keyed by topic and step 2 asks only
  what the write condition still needs.

Round 4, after fix round 3: 6 of 11 passed (V4, V5, V6, V7, V8, V11),
50 of 58 behaviour checks. V7 now writes the retro rule in the unit
folder and nothing in the main folder; V2 asked only what the write
condition needed. Left:
- V1, V2: every behaviour check passed; each run joined two read-only
  commands (`ls a; ls b`, `ls x || echo none`) in one call. Setup now
  says where `.dockerignore` and `.worktrees/.gitignore` are seen, one
  call each.
- AGENTS.md (V3, V9): without subagents the agent committed a part and
  reviewed it afterwards, without `diff HEAD`; compressing Review to 42
  lines had dropped "before the commit". Part folders now gives the
  order: edit, Review, commit on PASS before the next.
- plan (V3): the agent picked aegonex-plan for a concrete two-function
  request and deferred it to the next message; the one-step row now
  leads a request to make the change at once. The harness also gave a
  later turn only the agent's own brief and trace, not the user's first
  message, so turn 2 lost the requirements; later turns now carry the
  user's earlier messages word for word.
- done (V10): after the reviewed fix was committed, the brief reused the
  review's pre-commit result; every check now runs anew after the fix.

Round 5, after fix round 4, reran the seven scenarios the fixes touched:
5 of 7 passed (V1, V2, V6, V7, V10), 39 of 42 behaviour checks; with
V4, V5, V8 and V11 from round 4, 9 of 11. V1 and V2 joined no command,
V10 ran every check again after the fix's commit, and V3 opened its
task and ran its two parts in the unit folder at once. Left: V3 and V9,
both without a subagent tool, reviewed their own part before its commit
but left out `review not independent` (V9) or wrote it in Thai (V3),
and V3 ran `status --short` only after both commits. Review's reply is
now a line to copy: `PASS: <evidence>` / `FAIL: <evidence>`, ending
`(review not independent)` as is when the agent reviewed it itself, the
same parenthesis done's `Fixed:` line carries.

Round 6 reran V3 and V9: both now end each self-reviewed PASS line with
`(review not independent)`, reviewed before the commit and landed on
go. Left: V3 read `diff HEAD` for neither part (and `status --short` for
one), passing them on the test count alone; V9 closed with a status line
("Not yet landed. Say go ...") instead of the land question. As with the
marker, both became lines to copy: the PASS line names the diff
(`PASS: <done-when>, diff: <files>`), so a skipped read shows, and
the land question is `Land? push to <Base>, remove .worktrees/<u>,
aegonex/<u>: Not yet / go`.

Rounds 7 and 8 reran V3 and V9. The land question template held in all
four runs. Round 7 kept the PASS line in the trace only, since Review no
longer said it goes in the reply; it now opens `Reply per part:`. Round
8: V9 passed (one reviewed part, `PASS: ..., diff: README.md (review not
independent)` in the reply, the land question, then landed and cleaned
up). V3 fails as in every round: with two parts and no subagent tool it
runs each part's test and `status --short` before the commit, but reads
no `diff HEAD` and puts no PASS line in its report, taking the passing
tests as the review. Its unit, parts, tests, land and Clean up are right.

## Results that shaped v0.4.1 (2026-09-27)

The defect came from the lab, not from an agent. Scenario 21 in
`tests/lifecycle.sh` notes a fact in a task folder's `HANDOFF.md`, lands,
and watches Clean up's `worktree remove` refuse the folder; with exit's
commit first, the land and Clean up go through. The lab passed 134/134.

A new agent scenario, V12, forces the case: a task folder with no
milestone open, a Thai request to fix a typo and note a decision, then
"call aegonex-exit", go, go. One run each of V9 and V11 (regression) and
V12, Sonnet: 3 of 3 passed, every deterministic check green (V9 17, V11
15, V12 23). V12 ended turn 1 with the exit-first line and no land
question, exit's go reply ended with the land question, and the land go
removed the folder. Minor notes left for later: `ls` and `cat` with
relative paths, a trace naming a remote branch that does not exist, and
an exit brief whose Current work row lacked the no-ROADMAP suffix.

## Results that shaped v0.5 (2026-09-27)

The git labs came first: `tests/multi-repo.sh` 37/37 and
`tests/lifecycle.sh` 134/134, on every round below. A review round (22
confirmed findings) then changed `repos.md` and four SKILL.md files
within the line caps.

Agent scenarios, Sonnet, one turn per message, each graded by the
deterministic checks, the judge and a behaviour grader that reads the
traces:

- Round 1, ten scenarios: 5 of 10 passed (M2 parent plan, M6 consumer
  stop in a frontend session, M12b seven repos, V9, V12). The failures
  and their fixes: M1's go wrote no Repos section in backend and frontend
  (setup is now due when that heading is missing, and the fixture now
  commits the ticked steps' code); M3's land go skipped the consumer's
  check (now always run, and rerun after Sync); M9's note skipped the
  parent's `worktree list` (an agent miss; output right); M12a listed
  several nested repos where the guard allowed one (it now joins them);
  V1, a single repo, read `repos.md` (init now reads it only when step 1
  or a record sends it there).
- Round 2, the five failures plus M2: 4 of 6 passed (M3, M9, M12a, V1).
  M1 force-added admin's `.worktrees/.gitignore` with `git add -f` after
  git refused it (`scaffold.md` now says setup never adds that file); two
  of its fails were the harness (`diff -` cannot read stdin in the
  sandbox; the forbidden-flag check now also catches `add -f`). M2
  claimed the user had named the land order when they had not (a parent
  plan now takes it from the user's own words only, else an `(agent's
  call)` Decisions line).
- Round 3, M1, M2 and V1: 1 of 3 passed (V1). M1 left out the Repos
  section in backend and frontend, which round 2 had set up: the agent
  took init's step 2 table (setup only when the v0.4 heading is missing)
  over `repos.md`'s terse "or no Repos heading". That table and the Setup
  row now say it outright for a folder that holds repos. M2 met the skill
  but failed the harness's own over-specified expectation (the Repo column
  first); the expectation now accepts it in any position.
- Round 4, M1, M2 and V1: M2 and V1 passed; M1 met every v0.5
  expectation (Setup rows and one `chore: aegonex setup` per repo, the
  Repos section alone in backend and frontend, the full setup in admin,
  nothing in the parent) and failed only on `cd "<f>" && node --test`,
  as in round 1. That is a v0.4 limit, not a v0.5 one: in a harness whose
  shell goes back to its folder on every call, `cd "<f>"` and the command
  as two calls cannot work, so the agent chains them. Left for later (see
  the v0.5 spec's Risks). Also left: the harness's chain check missed that
  line (it strips any leading `cd "..." && `); a leader ticked a ROADMAP
  step during init's go.

Latest state of each scenario: M2, M3, M6, M9, M12a, M12b, V1, V9 and
V12 passed on their last run; M1 passed everything but the chained `cd`.

## Results that shaped v0.5.1 (2026-09-27)

The git labs: `tests/lifecycle.sh` 134/134 and `tests/multi-repo.sh`
37/37 (git 2.54.0) on each of the three texts below: the chain rule, then
Clean up's chain, then `cd "<P>"` dropped. Both labs now run a done-when,
and Clean up's remove, as the chain in a subshell, the way a shell that
keeps no `cd` runs it.

The harness changed with the rule. Every call starts in an unrelated
repository and keeps no `cd`; a command that starts with its own
`cd "<absolute folder>" && ` runs as written. V10 now starts in the main
folder, so its checks reach `.worktrees/m2` only through the chain.
`chains.py` reads each trace. After the prefix it allows one command or
the one chain, never for git or a read. Every install, test and done-when
must carry its own `cd`, and none may run from the session folder or on
the call after a bare `cd`. Clean up's remove must carry
`cd "<main>" && `, and its `cd` may not stand in the folder it removes.
Two harness faults were fixed along the way. `chains.py` first read only
list lines, so V10's trace passed with no command found. `check.sh` did
not write `final.diff`. The checks read only the leader's trace; a
subagent's commands show only in its transcript, which the graders read.

Round 1: six scenarios that run an install, a test, a done-when or a
Clean up (M1, M3, V1, V9, V10, V12), Sonnet, one turn per message, graded
as in v0.5. 2 of 6 passed (V1, V9).
- Every install, test and done-when ran as one call in its folder:
  - the leaders' 9 calls: V1's install, V10's seven checks over two
    turns, and M1's test;
  - M3's four reviewer test runs.
  None ran in the session folder or after a bare `cd`.
- V12 failed at Clean up. The agent left out the bare `cd "<main>"`, as
  V9 and M3 also did, and M1 and M3 left out `cd "<P>"`. In this shell
  that `cd` does nothing, but it is the same two-call pattern v0.5.1
  removes. So Clean up's remove became the chain (design, v0.5.1).
- M3 failed on two reads that chained a `cd` to the skill package:
  `cd "<skills folder>" && find . -type f | sort`. That breaks
  **Commands**, but it happened outside the project, and the harness line
  offers the own-`cd` form to any command.
- V10 and M1 failed for reasons outside v0.5.1:
  - V10's go reviewed its own fix although a subagent tool was present.
    Done step 7 says "without subagents, review it yourself".
  - M1's go reply had no Opened line, because `backend/.worktrees/m3`
    already existed.

Round 2, on the text with Clean up's chain: V9, V12 and M3 on a fresh
build, and M1 again (on the round 1 text: it runs init and its go, which
Clean up's change does not touch). 2 of 4 passed (V9, V12).
- Every Clean up remove ran as one call from the main folder: V9's,
  V12's, and M3's in backend and in frontend. No bare `cd` anywhere.
- Every install, test and done-when a leader ran was one call in its
  folder (M1's test, M3's two). M3's writers and reviewers ran the
  leader's `cd "<p>" && node --test`; V9's reviewer ran its grep the same
  way.
- Subagents in this harness never load the project's AGENTS.md, and the
  Dispatch and Review prompts carry no command rule. V9's writer and
  V12's reviewer each ran a check as one multi-line call, by absolute
  path, so on the right files (design, v0.5.1 known limits).
- M1 and M3 again left out `cd "<P>"`, as in every parent session so
  far, and M3's grader failed that clause. So `repos.md` drops it
  (design, v0.5.1).
- M1 failed outside v0.5.1:
  - a chained read of the skill package;
  - admin's new AGENTS.md without the Repos section, which v0.5 round 4
    wrote from the same text;
  - the review done by the leader itself with the Agent tool present, as
    in V10.
  The Opened line was back, so round 1's miss was variance.
- M3 failed outside v0.5.1, besides one chained read of the scenario
  folder. The leader committed the task folders' note, quoting Leader
  mode 5, "`<f>` work: commit it naming its files"; so turn 1 ended with
  the land question, not the exit-first line.

Round 3, on the final text (`cd "<P>"` gone): M1 and M3 on a fresh build.
0 of 2 passed: M1 outside v0.5.1, M3 on its subagents' commands.
- In the skills' steps, every command either leader ran that needs a
  folder was one chain: M1's test, `cd "<P>/backend/.worktrees/m3" &&
  node --test`, and M3's two Clean up removes, `cd "<P>/<r>" && git -C
  "<P>/<r>" worktree remove "<P>/<r>/.worktrees/t-discount"`. Neither
  trace has a bare `cd` or a chained read, and nothing ran from the
  parent. Outside those steps, M3's leader chained `||` onto two checks
  of the harness's output folder (turns 2 and 4, not in its trace).
- All six of M3's test runs were by subagents, each in its part folder.
  Three ended in an `; echo` of the exit code, which the leader's prompts
  asked for ("exits with status 0", "note the exit code"), and the
  frontend reviewer ran a bare `cd` before its chain; the writers also
  put several commands in one call. The checks passed 37/37, since they
  read only the leader's trace; the grader failed the test-form
  expectation (design, v0.5.1 known limits).
- M3 met every other expectation: the note written before dispatch and
  left uncommitted, so turn 1 ended with the exit-first line; exit and
  its commit per repo; one land question, backend first; frontend's
  landed check before its Sync; both repos landed and cleaned up in that
  order.
- M1 failed outside v0.5.1, with 31/31 checks and setup in all three
  repos (admin with the Repos section this time). The go reply again had
  no Opened line, since `backend/.worktrees/m3` already existed (2 of 3
  M1 runs), and the leader reviewed the step itself with the Agent tool
  present, as in round 2.

Latest state on the v0.5.1 text: V1, V9 and V12 passed on their last run;
V10 and M1 failed only outside v0.5.1, and M3 only on its subagents'
commands. The other scenarios were not rerun.

Left for later (outside v0.5.1):
- the review done by the leader itself with a subagent tool present (V10,
  M1 twice), where Leader mode 2 and 4 and done step 7 allow it only
  without subagents;
- init's go without the Opened line when the unit folder already exists
  (M1, 2 of 3 runs);
- the Dispatch and Review prompts: no command rule, and Dispatch's
  "commit there" for a part in `<f>` (V9, V12, M3);
- Leader mode 2 and 5 commit `<f>` work, a note's HANDOFF.md included
  (M3);
- "Reply per part" does not say the report repeats the reviewer's line;
- a leader ticking the ROADMAP step itself (M1, rounds 2 and 3);
- a task's `done when:` note line has no owner (note, lines 40-41);
- a new AGENTS.md in a repo under a parent: `scaffold.md` does not name
  the Repos section (M1);
- reads by a relative path (V1, V9, M1);
- `Next:` when there is no ROADMAP;
- init's "no HEAD sha" against the New commits row;
- the Thai example brief, which lacks the move rows;
- in a parent session:
  - the go reply's clause order: setup clauses not led by `<r>: `, and
    once setup committed after the step (M1);
  - note lines in English under a Thai reply, note's grep skipped, and
    no Noted line;
  - the note written after the parts merged, though section 7 puts it
    before dispatch;
  - the landed check not rerun after Sync: section 7 leaves it out,
    though section 3 asks for it;
  - the land order not shown as `(agent's call)`;
  - the land go's paths without `<r>/`: section 7's reply form against
    section 1.

## Results: review by a fresh subagent whenever the tool exists (2026-09-27)

The git labs: `tests/lifecycle.sh` 134/134 and `tests/multi-repo.sh`
37/37 (git 2.54.0), on the round 1 text and on the final text, each run
with `AEGONEX_RUN` under the session scratchpad. The real repository's
refs were the same before and after.

The harness is v0.5.1's, copied, with one rule added. V10's go and M1's
go expect the step's **Review** to be a fresh read-only subagent, started
after the edit and before the commit, never the leader or the part's
writer, and a reply line without `(review not independent)`. A leader
that reviews its own part fails, with or without the marker; only an
agent with no subagent tool may. The grader's `subagents_used` item now
asks who reviewed each part, when, and what the reviewer ran. `check.sh`
(V10) and `mcheck.sh` (M1) gained two turn-2 checks: the reply has no
marker, and the trace names a reviewer the agent started. That second
check, `revsec.sh`, reads the trace's "Subagents started" part or a list
item led by "Subagent", and fails on "none". It took three tries: a grep
for both words on one line missed V10 round 1's reviewer (two lines); an
`awk` from the first "subagent" passed M1 round 1 on the leader's own
review line; the section-only form missed M1 round 2's list item. The
graders read the transcripts and each reviewer's `.meta.json`
(`parentAgentId`), so no verdict rested on these checks.

Round 1, on the first text (Leader mode 2 `for 2+ parts with a subagent
tool (else one by one in <f>: edit, **Review**, commit on PASS)`, Leader
mode 4 and done step 7 as they stand now): V10 and M1, Sonnet, one turn
per message. 0 of 2 passed; the rule held in V10 only.
- V10 held the rule. The leader fixed `REFRESH_WINDOW_S`, then started a
  fresh general-purpose reviewer, which reran `bash
  tests/check-refresh.sh` in `.worktrees/m2` and read `status --short`
  and `diff HEAD`. It returned PASS, and then the leader committed. The
  new brief read `Fixed: src/auth.ts committed`, without the marker. The
  checks passed 20/21 (with `revsec.sh`). The grader failed turn 1 on a
  chained read, `cd "<m2>" && grep -n ... src/auth.ts`, used to see which
  condition of the check failed: v0.5.1's known limit, outside this
  change.
- M1 failed the rule. The leader wrote the test and reviewed it itself:
  it ran `node --test`, read no status or diff, and committed. Its trace
  says the step "touched one file group in one folder, so Leader mode's
  "one part in `<f>`" path was used (edit, review, commit directly)". It
  never quoted item 4. The grader traced the choice to item 2's else,
  which listed **Review** between two things the leader does and named
  no reviewer. The reply had no marker either, so a self-review read as
  independent. Checks 32/33 (with `revsec.sh`).

Round 2, on the final text (item 2's else reads `edit, subagent
**Review**, commit on PASS`): V10 and M1 on a fresh build. 0 of 2 passed,
but the rule held in both.
- M1 held the rule. The leader wrote the test, ran `node --test`, then
  started a fresh Explore (read-only) subagent, "Independent review of
  discount test". The reviewer ran `cd "<m3>" && node --test`, `git -C
  "<m3>" status --short` and `git -C "<m3>" diff HEAD --
  test/cart.test.js`, and returned `PASS: node --test passes, diff:
  test/cart.test.js`. The leader committed after that. The reply opened
  with `**เปิดแล้ว:** backend/.worktrees/m3` and ended with the reviewer's
  PASS line, without the marker. Checks 33/33. The grader failed one
  clause outside this change: the PASS line is not led by `backend: `.
  Repos section 7 shows that lead only for dispatched parts
  (`frontend p1: PASS: ...`), and round 1's line lacked it too. The
  leader's prompt also narrowed the reviewer's diff to the file it named.
- V10 held the rule, and failed on what followed a FAIL. Both reviewers
  were fresh general-purpose subagents, started after the fix and before
  the commit. The first returned FAIL on `docs/scratch/try.md`, a Scratch
  file that was there before the fix ("new files" does not say new since
  when). The leader did not reply `FAIL: <evidence>` or redo the part. It
  started a second reviewer on the same diff, whose prompt said a
  previous reviewer "wrongly flagged" the file, and committed on its
  PASS. The brief read `Fixed: src/auth.ts committed`, without the
  marker, and did not mention the first FAIL. The checks passed 19/21.
  One FAIL was a harness artefact: the agent mistyped the snapshot path,
  so `after1.txt` was empty, and the grader found turn 1 wrote nothing
  from the reflogs, the history and its tool calls. The other was a
  chained read, `cd "<run>/V10" && ls -la`, run after the failed snapshot
  command. Both reviewers ran `; echo` of the exit code and `;`-chained
  git, as the leader's prompts invited.

Round 3, on the same final text: V10 and M1 again on a fresh build, to
see whether round 2's result on the rule was chance.
1 of 2 passed (V10); the rule held in both.
- V10 held the rule and passed, 21/21. The leader fixed the line, then
  started a fresh Explore reviewer. The reviewer reran the check in
  `.worktrees/m2` and read status and `diff HEAD`, then returned FAIL on
  the same Scratch file: the leader's prompt asked it to list "any new
  (untracked) files" and to fail on anything unexpected, and never said
  the file was there before. The leader replied as step 7 says, `FAIL:
  docs/scratch/try.md is untracked and unrelated to the fix`, committed
  nothing, and ran every check again from step 3. The grader passed every
  expectation and found a gap outside this change. After a FAIL the fix
  stays uncommitted in `<f>`, so the checks pass on the working tree ("4
  of 4 checks passed") while `aegonex/m2` still holds 120, the brief does
  not name the file, and the next go's step 1 would commit the failed
  fix as `wip: m2 before close` with no review.
- M1 held the rule and failed on what its reviewer read. The leader
  wrote the test, then started a fresh general-purpose reviewer, which
  returned `PASS: node --test passes, diff: test/cart.test.js`; the
  commit came after it. The checks passed 33/33. The leader's prompt
  asked only for `node --test` and `git -C "<m3>" diff HEAD --
  test/cart.test.js`, so the reviewer read no status, no whole diff and
  no new files, which Leader mode 4 asks for; the grader failed the
  review expectation on that. The report paraphrased the reviewer's line,
  `ตรวจทานอิสระผ่านแล้ว (PASS)`, in a line led by `backend:`. The leader
  also ran one chained read, `cd "<shop>/admin" && ls -pL ...`, that its
  trace records without the `cd`.

On the final text, all four leaders (V10 and M1, rounds 2 and 3) had a
subagent tool and started a fresh reviewer after the edit and before any
commit; none reviewed its own part, and no reply carried the marker. On
round 1's text, V10 did the same and M1 did not. This closes the first
item of v0.5.1's "Left for later". Every scenario that failed on the
final text failed on what the review read or what followed a FAIL, not
on who reviewed.

Left for later (outside this change):
- "new files" (Leader mode 4) and "every new file" (done step 7) do not
  say new since when. An untracked Scratch file from before the fix read
  as the fix's, and the reviewer failed a correct fix in V10 rounds 2 and
  3 (v0.5.1's self-reviewing leaders never failed on it);
- what follows a reviewer's FAIL: Leader mode 4 and 5 do not say it
  stands (V10 round 2 started a second reviewer with a prompt that argued
  against the first); after a FAIL on a go's fix, done step 7 reruns the
  checks on the uncommitted fix, and the next go commits it as `wip`
  unreviewed (V10 round 3);
- the Review prompt: Leader mode 4 lists what the reviewer reads but no
  prompt to hand over, so leaders narrowed the diff to one file and left
  out status and new files (M1 rounds 2 and 3); the prompts carry no
  command rule, and reviewers ran `; echo` of the exit code and
  `;`-chained git or reads (V10 in every round, M1 round 3); a
  general-purpose reviewer has write tools and is read-only only by its
  prompt;
- the report's review line: nothing says it repeats the reviewer's
  `PASS:` line (M1 round 3 paraphrased it), and in a parent session the
  line of a part in `<f>` is not led by its repo, since repos.md section 7
  shows the lead only for dispatched parts (M1 round 2);
- M1's turn-1 first step: round 2 left out its folder and the `set up
  aegonex` preparation, and round 3 named only backend's setup, though
  the go set up all three repos (repos.md section 5 does not say how);
- reads chained to a `cd` (V10 rounds 1 and 2, M1 round 3), as in
  v0.5.1; M1 round 3's is missing from its trace, which is all
  `chains.py` reads.

## Results for a parent session's notes and land go, and init's Opened line (2026-09-27)

The fixes to the parent-session and init-go items of v0.5.1's "Left
for later" (design, "A parent session's notes and land go, and init's
Opened line"). The git labs: `tests/lifecycle.sh` 134/134 and
`tests/multi-repo.sh` 37/37 (git 2.54.0) on each text below, the final
one included.

The harness changed with the fixes:
- M1's go expectation asks for the Opened line naming
  `backend/.worktrees/m3`, a folder that existed before the go.
- M3's turn 1 asks for note before any part folder or dispatch, its
  steps 1-6 in each repo, the text in Thai (the land-order decision
  included, ending `(agent's call)`), note's grep on each file written,
  and a reply that opens with the `จดแล้ว (<ประเภท>) ใน <repos>: <text>`
  lines.
- Before M3's turn 4, `teammate.sh` puts a teammate's commit on
  frontend's origin main (plumbing, no push, so `push-order.log` stays
  the session's own). The land go's Sync in frontend then merges it, and
  turn 4 asks for the landed check again after that Sync, and for reply
  paths written `<r>/.worktrees/<u>`. In every M3 round before, Sync
  merged nothing, so the rerun was never exercised.
- The graders also read the transcripts of each turn's agent and its
  subagents, not only the traces.
The harness lived in the session scratchpad, which was emptied before
this was written; the transcripts were kept, and run 4 below is read
from its transcript.

M1 (Sonnet, on the text with the Opened line, `scaffold.md`'s Repos
line and note's changes; M1 reads none of the later section 7 edits):
- Turn 2's reply opened with `**เปิดแล้ว:** backend/.worktrees/m3`,
  although the folder existed before the go (v0.5.1 rounds 1 and 3 left
  the line out for the same folder, round 2 wrote it).
- admin's new AGENTS.md has the Repos section, from `scaffold.md`'s new
  line (v0.5.1 round 2 wrote it without).
- Checks 30/31; the grader failed M1 outside this work: turn 1's chained
  reads (`cd "<P>" && pwd && ls -la`, `cat ... || echo`), the leader's
  own review with the Agent tool present (`review not independent`), and
  `docs: M3 step 3 done`, a ROADMAP.md tick the leader committed.

M3 turn 1 ran four times, the text changing between runs:
- Run 1, on the first text. Note ran before dispatch, its grep on each
  HANDOFF.md, the done-when in Thai, the record, and a decision in each
  repo; but the decision copied section 7's quoted English
  `backend lands first (agent's call)`, and the reply opened with the
  review lines, no Noted line, although the leader had read note's step
  5 and section 8. So section 7 now says note's reply lines open the
  report.
- Run 2: the reply opened with the noted lines. But every note line was
  English, and the leader committed the notes before dispatch
  (`docs: note t-discount`), so turn 1 ended with the land question, as
  in v0.5.1 round 2. It also chained `cd "<P>/backend" && git ...`,
  made a part folder inside the task folder and deleted its branch with
  `branch -D`, and dispatched in the background, then stopped; the
  harness session relayed each subagent's final message to it word for
  word. Not continued. Section 7 now describes the decision instead of
  quoting it.
- Run 3, all four turns (below). Turn 1 wrote the notes before the part
  folders, in English, then rewrote both files in Thai after the parts
  merged, quoting note's language rule. So section 7 names the language.
- Run 4, turn 1 only, on the final text. The notes were Thai on the
  first write (`decision: backend land ก่อน frontend (agent's call)`, the
  done-when lines, frontend's record), written before any part folder,
  with the grep on each HANDOFF.md after it. But the leader committed
  them (`chore: notes for t-discount (HANDOFF.md)`), as in run 2, so the
  turn ended with the land question, and the reply opened with a summary
  of the notes, not the `จดแล้ว` lines. It also made `out/turn1` in the
  parent folder and removed it (the harness's output path).

M3 run 3 (Sonnet, four turns): checks 36/37, grader FAIL.
- Turn 1: `จดแล้ว (ตัดสินใจ) ใน backend, frontend: backend land ก่อน
  (agent's call)` and three more noted lines opened the reply, then the
  review lines led by the repo, then the exit-first line; nothing
  committed. Two writers and two fresh reviewers, each test as
  `cd "<part folder>" && node --test`; the backend writer ran add and
  commit in one multi-line call with `$(cat <<'EOF' ...)`. The grader
  failed the note's first English write.
- Turn 2: one exit brief for both repos; frontend's HANDOFF.md kept the
  record as a Note line. Its Stopped at and Next step are English under
  a Thai brief, and were committed and pushed; the grader failed that.
- Turn 3: `backend b683f7b · frontend 69cbecd`, then the land question,
  backend first. The one failed check wants the literal `Land?`; the
  agent wrote the question in Thai, and section 7 and AGENTS.md give
  only `ยังไม่ land` in Thai, so the grader found the check wrong.
- Turn 4: frontend's landed check before Sync; Sync merged the
  teammate's commit; the check again; **Land**; Clean up as the chain;
  pushes backend, then frontend. The reply: `backend: ... ลบ
  backend/.worktrees/t-discount แล้ว`, the same for frontend, then
  `ต่อไป:`.

Latest state: init's Opened line, the Repos section in a new AGENTS.md
under a parent, the landed check after a Sync that merged, and the land
go's `<r>/` paths passed where tested (M1, M3 run 3). Note in a parent
session met every point in some run, but no single run met all: run 3
missed the first write's language, run 4 the Noted form and, through
Leader mode's commit, the exit-first line.

Left for later:
- Leader mode 2 and 5 commit `<f>` work, the notes included, before
  dispatch (M3 runs 2 and 4); the turn then ends with the land question,
  not the exit-first line;
- the leader's reply form for notes written before dispatch: run 4 led
  with a summary, not note's `จดแล้ว (<ประเภท>) ใน <repos>:` lines;
- exit writes HANDOFF.md's Stopped at and Next step in English under a
  Thai brief (M3 run 3, turn 2); its step 7 read-back checks only the
  length;
- the whole Thai land question, or a line saying `Land?` stays English
  like `go` (M3 run 3, turn 3; `mcheck.sh` expects `Land?`);
- the leader's own review with a subagent tool present, and a ROADMAP.md
  tick by the leader (M1);
- the Dispatch prompt carries no command rule (M3 run 3's writer);
- chained reads and git after a `cd` (M1 turn 1, M3 run 2), reads by a
  relative path (M3 run 3);
- Sync's `<Base>` pair, which backend's Sync skipped (M3 run 3);
- after a Sync that merged code, the land go pushes without running the
  done-when again (the grader's observation, harmless here);
- a leader that dispatches in the background and stops before its
  subagents finish (M3 run 2).
