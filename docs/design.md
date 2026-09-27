# Design

## Problem
Work spans many sessions and several AI agents. Each session starts by
re-typing the same context, and state is lost when a session ends or the
context window fills up.

## Shape
- State lives in the project repo as three markdown files with different
  rates of change: `AGENTS.md` (rules, stack, commands: rarely changes),
  `ROADMAP.md` (direction and milestones: changes per milestone),
  `HANDOFF.md` (exact resume point: rewritten every session).
  `CLAUDE.md` is `@AGENTS.md` plus one sentence (Claude Code reads
  `AGENTS.md` only through that import).
- Every change, a one-line fix included, happens in a unit folder: a git
  worktree `<main>/.worktrees/<u>` on branch `aegonex/<u>`, while the main
  checkout stays on the base branch. `ROADMAP.md` and `HANDOFF.md` are
  written in the open milestone folder. Big work is split into parts that
  subagents write in their own folders, each checked by a separate
  reviewer. Landing, pushing and removing a folder need a go that names
  them (v0.4 spec below).
- Spot-level state stays in the code as anchor comments (`AIDEV-TODO`,
  `AIDEV-NOTE`), found with grep. The grep never counts the four state
  files themselves.
- Skills are siblings, one per verb (`aegonex-init`, `aegonex-plan`,
  `aegonex-note`, `aegonex-exit`, `aegonex-done`). No skill depends on arguments: only Claude Code
  substitutes them, every other agent passes trailing text as plain prompt.
- Each state file has exactly one writer. `aegonex-init` creates
  `AGENTS.md` and `CLAUDE.md` when they are missing, or appends the two
  v0.4 sections to them, and commits that setup, only after the user says
  go. `aegonex-plan` owns the structure of `ROADMAP.md`.
  `aegonex-exit` owns `HANDOFF.md`, including its first creation, and may
  only tick steps, add decisions and list new documents in `ROADMAP.md`.
  `aegonex-note` may only append one line under `## Session log` in
  `HANDOFF.md`, the moment a decision, dead end or environment fact
  appears, so a session that never reaches exit still leaves testimony.
  `aegonex-done` retires: it collapses a closed milestone in `ROADMAP.md`
  and proposes deleting the documents that milestone listed, then lands
  the unit and removes its folder and branch on the same go. Three writers
  of `ROADMAP.md`, three disjoint operations: grow, mark, retire.
- `aegonex-init` is the single entry point of every session. It reads and
  briefs, and writes nothing before the user answers the brief's question.
  On go it touches an existing file only to append the setup sections, and
  it moves uncommitted work into a unit folder and opens that folder.
- `aegonex-exit` is the single exit of every session. It writes from
  evidence the session produced, commits only on go (it proposes the
  commit), pushes unfinished work only when the user asks for it, never
  writes any part of a secret, and ends by naming `aegonex-init` as the
  next entry.
- This repository holds instructions and empty templates only. No project's
  filled `ROADMAP.md`/`HANDOFF.md` ever lives here.
- Compaction cannot be triggered by a skill; it is a harness action the user
  or the harness runs. The exit brief therefore hands the user the exact
  command (`/compact`, then `aegonex-init`). A Claude-Code-only enhancement
  for later: a `SessionStart` hook with the `compact` matcher that re-runs
  the init brief automatically after every compaction.
- Briefs are written for a reader who may not know git or the skills'
  words: a bold title, one markdown table whose rows appear only when they
  have something to say, a bold action line, and the question last. No
  emoji or icon. Where the harness has a multiple-choice question tool
  (Claude Code: `AskUserQuestion`) the question is asked with it; elsewhere
  the last line carries a bold **go**. Every reply is in the user's language
  (v0.3 spec below).

## Portability rules (verified 2026-09)
- Frontmatter uses only the six spec fields: name, description, license,
  compatibility, metadata, allowed-tools.
- `name` equals the directory name, lowercase and hyphens, at most 64 chars.
- `description` carries the trigger phrases (most agents pick skills by
  description alone) and never summarises the workflow.
- No Claude-only body features: `!` shell blocks, `@file`, `${CLAUDE_*}`.
- SKILL.md stays under 500 lines; supporting files are referenced by
  relative path.
- One canonical copy in `~/.agents/skills/<name>`; Claude Code needs a
  symlink in `~/.claude/skills/`, the others read `~/.agents/skills` natively.
- Verified nuances (2026-09-02): no shipped runtime rejects extra frontmatter
  keys (Claude Code 2.1.258 is permissive; Codex's parser ignores unknown
  keys), only optional validators do, and Codex's bundled `quick_validate.py`
  allows five fields without `compatibility`. Cursor also scans
  `~/.claude/skills` for compatibility and does not deduplicate, so it may
  list a skill twice. OpenCode picks one of the duplicate roots per session
  (issue #29950). Neither is fatal; both are reasons to keep exactly one
  canonical copy plus the single Claude symlink.

## Rules embedded in the skills
1. git is the truth, files are testimony: a contradiction is reported,
   never silently trusted.
2. HANDOFF.md is at most one page and is overwritten, never appended.
3. Never duplicate what already has a home (commits, specs, diffs): link the
   path instead.
4. HANDOFF.md records dead ends tried, so the next session does not repeat
   them.
5. HANDOFF.md names the skills the next session should use.
6. No secrets in any of the three files.
7. Suggest a handoff when the context starts to feel heavy, before it fills.
8. Every step in ROADMAP.md carries a `done when` that can be checked (a
   command, a test, a visible behaviour). A step is ticked only when that
   check was observed in the session.
9. A document created for a milestone is listed under that milestone's
   `docs:` line in ROADMAP.md. A skill deletes only listed documents and
   files under the `Scratch:` directory declared in AGENTS.md, and only
   through a commit command the user approved.
10. A decision, a dead end or an environment fact is written to the
    Session log of HANDOFF.md when it happens, not at exit.
11. A closed milestone leaves one lesson behind: done proposes turning a
    dead end into a rule in AGENTS.md, in the same commit.

## v0.5.1 (2026-09-27): commands that need a folder, in any shell

The defect (v0.5 Risk 14): v0.4 rule 3 runs the install as `cd "<f>"` on
its own call, then the install command on its own call, and runs other
commands "in the unit folder (the shell's working directory)". That
assumes the shell keeps its folder between calls. Some harnesses start
every call in the session's folder: Claude Code moves the shell back
after a `cd` out of the session's folder (`Shell cwd was reset to
<folder>`), and Codex-style harnesses take the folder as a parameter of
each call. There the second call runs the install or the tests in the
session's folder: the wrong checkout, or no project at all in a v0.5
parent session. Agents that notice chain the two, `cd "<f>" && node
--test`, against the rule (scenario M1, v0.5 rounds 1 and 4). A done-when
check (done step 3, Leader mode's Review) has the same problem.

Candidates, weighed for what a weaker model follows:
1. One chain form, `cd "<absolute folder>" && <command>`, allowed only
   for the commands that need a folder: an install, a test, a done-when.
   Git stays `git -C "<folder>"`; reads take absolute paths. It works in
   both kinds of shell: where a `cd` is kept, the chain leaves the shell
   in the folder, as v0.4's `cd` did; where the shell resets, the command
   still runs in the folder; a failed `cd` stops it before it runs
   anywhere else. It is the form agents already reach for.
2. Tool flags (`npm --prefix`, `node --test <folder>`, `make -C`, `go
   -C`, `cargo --manifest-path`): no chain, but a form per tool, none for
   a done-when script with relative paths, and not every flag moves the
   working folder: `node --test <folder>` run from elsewhere finds the
   folder's tests but runs them from the caller's folder, so a test that
   reads a file by a relative path fails (checked on Node 26, where `npm
   --prefix <folder> test` and the chain pass).
3. A subshell, `(cd "<f>" && <command>)`: leaves the shell where it was,
   but POSIX only, and one more form to learn.
4. The harness's folder parameter (Codex's `workdir`): right where it
   exists, but AGENTS.md cannot name one for every harness; an agent that
   uses it breaks nothing, since the command runs in the folder.
5. v0.4's two calls plus "chain them if the shell resets": two forms, and
   the model must first know which shell it has; a wrong guess runs the
   tests in the wrong folder with no error.

Decision: 1. One form, written where each command runs, needs no
knowledge of the shell, fails loudly on a wrong folder and keeps the rest
of rule 3 checkable: an `&&` only after a leading `cd "<absolute
folder>"`, followed by one command; `||`, `;`, `; echo $?` and `|| true`
stay forbidden.

The same form for Clean up's remove, decided after the first scenario
round. v0.4 moves the shell out of `<f>` with `cd "<main>"` on its own
call before Clean up, since Windows cannot delete a folder a shell stands
in. Where the shell resets, that `cd` does nothing, and the agents left it
out of every land (V9, V12, M3); where the shell keeps its folder, an
agent that leaves it out stands in `<f>`, and on Windows the remove fails
part-way. One call, `cd "<main>" && git -C "<main>" worktree remove
"<f>"`, cannot be run apart from its `cd` and works in both kinds of
shell.

`repos.md`'s `cd "<P>"` goes too, decided after the second round. v0.5
put it on its own call after every `cd` in a parent session, so that a
shell left in one repo would not run the next repo's test there (Risk 6).
The chain now names the folder of every command that needs one, so a
shell left in a repo's folder changes only a command that already breaks
**Commands** (a relative path). Where the shell resets, `cd "<P>"` does
nothing, and the agents left it out of every parent session (M1 and M3,
both rounds). A `cd` now appears only at the head of a chain.

Changes (line counts: SKILL.md 1,415 unchanged, with init 323, plan 225,
note 137, exit 352, done 378; `repos.md` 99, one fewer; `scaffold.md` 89;
the AGENTS.md sections 43 lines, longest 125):
- `assets/AGENTS.md`, in place under the same `(aegonex 0.4)` headings:
  **Commands** allows `cd "<folder>" && <command>` for an install, a
  test, a done-when and a remove; **Open** runs `cd "<f>" && <install>`
  as one call; **Clean up** drops its bare `cd "<main>"` and removes the
  folder as `cd "<main>" && git -C "<main>" worktree remove "<f>"`.
- init: the go names the install as the one chain; a red flag, "I'll `cd`
  into the unit folder, then run the install on the next call";
  `scaffold.md` move step 9 is the chain, with the reason.
- plan: the command rule and its red flag allow **Open**'s install.
- done: a check, the tests and the install run as the chain; step 3
  shows it; step 7.4's remove is the chain from `<main>`, with the reason;
  the red flag names any other chain, or a check or a remove run on the
  call after a bare `cd`.
- done and `scaffold.md`: PowerShell 5.1, `Set-Location "<f>"` (Clean
  up: `"<main>"`), then the command.
- `repos.md`: sections 1 and 7 drop `cd "<P>"`.
- exit: its command rule and red flag allow Remove's **Clean up** chain
  (done step 7.4); it runs no install or test. note: the version only.
- All five skills `0.5.1`. `tests/lifecycle.sh` runs its two done-when
  checks, and both labs run Clean up's remove, as the chain in a
  subshell, as a shell that keeps no `cd` runs them; `tests/multi-repo.sh`
  drops its `cd` into each repo before Clean up and its `cd "$P"` after
  it; still 134 and 37 checks.

Kept: git as `git -C` and reads by absolute path, never a `cd` for
either.

Known limits:
- Windows PowerShell 5.1 has no `&&`: the line does not parse and
  nothing runs. The fallback, `Set-Location` then the command, needs a
  shell that keeps its folder. PowerShell 7, cmd, bash, zsh and dash run
  the chain.
- Projects set up before v0.5.1 keep their copy of the sections: setup
  appends only a missing section, and the headings stay `(aegonex 0.4)`.
  The skills carry the rule for their own steps; an agent without them
  reads the old two-call rule there.
- The Dispatch prompt (Leader mode 3) names the install command, not the
  chain, and neither it nor Review's prompt carries the command rule
  (their lines are full). A subagent that does not load the project's
  AGENTS.md (none did in the scenario harness) keeps the rule only as far
  as the leader writes it. Every subagent test ran in its part folder,
  but V9's writer and V12's reviewer each ran a check as one multi-line
  call. In M3's last round three of six test runs ended in an `; echo` of
  the exit code, which the leader's prompts asked for, and a reviewer ran
  a bare `cd` before its chain.
- Where the shell keeps its folder, the chain leaves it in `<f>`, as
  v0.4's `cd` did, and Clean up's leaves it in `<main>`; in a parent
  session nothing takes it back to `<P>`.
- Leader mode's Integrate removes a part folder as `git -C "<f>" worktree
  remove "<p>"`, with no `cd`, as in v0.4: a Windows shell that keeps its
  folder and still stands in `<p>` (after that part's install) fails
  part-way. **Commands** lists a remove among the chains, so an agent may
  run `cd "<f>" && ` first; the Integrate line has no room to show it.
- The chain form spread to reads: in four scenario turns an agent listed
  a folder outside the repos with `cd "<folder>" && find ...`, against
  **Commands**: the skill package three times, the scenario folder once,
  none in the last round. Nothing was changed; the check flags it.

The labs and the agent scenarios, run in a harness that starts every call
in an unrelated folder, are in `docs/testing.md`.

## v0.5 spec (2026-09-27): a project made of several repos

Why: v0.4 is written for one git repo. The owner's projects are mostly a
plain parent folder holding 3-5 repos (`~/Code/shop/` with `backend/`,
`frontend/`, ...), and most features change backend and frontend. Opened in
that folder, every skill's first command (`git -C "<here>" worktree list
--porcelain`) fails and no skill says what to do next, so an agent may
improvise `git init` in the parent and wrap the child repos. Nothing opens
the matching unit in a sibling repo, orders the landings (an API before its
caller), or handles one repo landed while another waits for a pull request.

The owner's answers (2026-09-27), binding:
1. Sessions open mostly in the parent folder (not a repo), sometimes inside
   one repo, lately sometimes one session per repo in parallel.
2. Each repo keeps its own plan (its own ROADMAP.md and HANDOFF.md), so
   agents can work on repos in parallel.
3. A feature often changes several repos (most touch backend and frontend).
4. 3-5 repos per project.

R1-R3 and the other v0.4 requirements hold per repo, unchanged. Scope
stays small: every stop state is an ordinary v0.4 state in each repo plus
one small record that git can check, so any later session, in the parent
or in one repo, resumes it. There is no parent file, no progress file, no
lock and no feature id.

How it was made: three designs (minimal change, parallel first,
correctness first), three judges. Two picked the correctness design, the
base, which was cut down with the minimal design's pieces and checked over
12 cases. Where the judges disagreed, the reason stands beside the choice.

### Names

| Thing | Name |
|---|---|
| parent folder | `<P>`: the folder the session opened in (the harness's working folder, else the first `pwd`), held for the whole session, never the shell's folder after a `cd`; not a repo |
| repo of the project | `<r>`: a direct child folder of `<P>` for which `git -C "<P>/<r>" rev-parse --show-prefix --git-dir` prints an empty line, then `.git` (a subfolder of a repo prints its prefix, a linked worktree an absolute git dir; a plain folder exits 128) |
| sibling path | `<P>/<r>`; from inside one repo, `<main>/../<r>`, whichever folder of the repo the session is in (the Repos section's `<main>/../<repo>`) |
| cross-repo task | the same `t-<slug>` in every repo it changes (`-2` where an old pull request holds the name; the record names the real unit) |
| milestone pair | each repo's own next `m<n>` (backend `m3`, frontend `m5`), joined by a record |
| record | `after: <r> <v>`, `<v>` = `m<k>` or `t-<slug>`, lowercase like the unit ids; several: `after: backend m3, auth t-token`; `after:` stays English like `done when:` |
| provider / consumer | the unit a record names / the unit that holds the record |
| landed | task `t-<s>`: `aegonex/t-<s>` is gone in `<P>/<r>`; milestone `m<k>`: `aegonex/m<k>` is gone there and ROADMAP.md on its `<remote>/<Base>` holds `- [x] M<k> — <name> · closed <date>` |
| land order | a unit after every unit its record names; otherwise folder-name order |
| Repos section | `## Repos (aegonex 0.5)`: the 7 lines of `assets/AGENTS-repos.md`, appended to AGENTS.md only in the repos of a multi-repo project |

### Rules (added to v0.4's 1-6)

7. Nothing is ever written in `<P>`: no `git init`, `clone`, file, folder or
   `.worktrees`. Only the error `not a git repository` enters parent mode;
   any other error (`dubious ownership`, ...) is quoted and stops.
8. Each repo is a v0.4 project: its own Base and Remote, `## Commands`,
   `.worktrees/`, state folder and Rules 1-6 (Rule 6 per repo).
9. A record lives only in the consumer, only in a repo with the Repos
   section, and only a session opened in `<P>` writes it: that session has
   read both repos and set up the section, while plan and note stay v0.4
   inside one repo. The provider carries nothing about its consumers.
10. A consumer lands (the task land question, `aegonex-done`, exit's push
    what I have) only after the landed check passes. From `<P>`, a
    cross-repo task lands on one go, providers first; the first repo that
    does not finish Clean up stops the rest. Milestones close one unit per
    `aegonex-done` run.
11. A sibling is only read: the landed-check commands and its AGENTS.md.
    Nothing there is fetched, switched, opened or committed.
12. One session per repo at a time; a parent session holds each repo it
    opens a unit in. A `worktree add` refusal (`already exists`, `already
    checked out`) means another session holds the unit: quote it and stop,
    never retry under another name. In a repo with the Repos section a
    milestone number, once written, never changes.

### Layout

```
~/Code/shop/                        <P>: not a repo; aegonex writes nothing here, ever
  backend/                          repo; its <main> stays on its own Base
    AGENTS.md                       the v0.4 sections (43 lines, unchanged) + the Repos section (7 lines)
    CLAUDE.md, .worktrees/.gitignore unchanged
    .worktrees/m3/                  aegonex/m3: backend's ROADMAP.md, HANDOFF.md (its state folder)
    .worktrees/t-discount/          half of a cross-repo task
    .worktrees/t-discount--p1/      a part folder of it, under backend's <main>
  frontend/
    AGENTS.md, CLAUDE.md, .worktrees/.gitignore   as backend
    .worktrees/m5/ROADMAP.md        `- [ ] M5 — cart page · after: backend m3 · done when: <observable>`
    .worktrees/m5/HANDOFF.md        may hold `t-discount after: backend t-discount`
    .worktrees/t-discount/
  admin/                            a repo not set up yet: set up on the next parent init's go
  docs/, notes.txt                  not repos: skipped
```

- Worktrees and part folders stay inside their repo, never in `<P>`.
  Install and test lines come from each repo's own `## Commands`, and a
  harness-made worktree is adopted per repo, as in v0.4.
- New in the skills repo: `aegonex-init/references/repos.md` (the
  procedure; the other skills cite it as `../aegonex-init/...`),
  `aegonex-init/assets/AGENTS-repos.md` (the Repos section),
  `tests/fixtures/make-multi-fixture.sh` and `tests/multi-repo.sh`.

### The three session modes

(a) Opened in the parent folder (the usual case). Every skill's first
command, its v0.4 `worktree list` on `<here>` (the folder the session
opened in), fails there with `not a git repository`; the skill's pointer
sends it to `repos.md`, whose section for that skill replaces the step.
- Find the repos (section 1): `ls -pL "<P>"` (PowerShell `Get-ChildItem
  -Directory -Name -LiteralPath "<P>"`, cmd `dir /b /ad "<P>"`), then one
  `git -C "<P>/<d>" rev-parse --show-prefix --git-dir` per folder not
  starting with `.`. An empty line, then `.git`: a repo; exit 128 (a
  subfolder or a linked worktree of a repo prints something else): skipped; another fatal error: a row `<d>: not read: <first error
  line>`. No other git command names `<P>`. No repo: the whole reply is
  `<P> is not a git repo and holds none: create or clone one yourself, then
  run aegonex-init in it`; more than 6: `<P> holds <n> repos; open the
  session in one of them`. Both write nothing.
- Each repo is a v0.4 project with `<main>` = `<P>/<r>`; each skill runs
  its steps per repo, rows and reply lines led by `<r>: `, paths written
  `<r>/.worktrees/<u>`. After every `cd` (an install, a test, Clean up's
  `cd "<main>"`), `cd "<P>"` on its own call; git stays `git -C`. (v0.5.1:
  each of those `cd`s heads its command's one call, `cd "<folder>" && `,
  and `cd "<P>"` is gone.)
- init (section 5) glances at each repo (`worktree list`, `branch
  --show-current` and status of `<main>`, its AGENTS.md and ROADMAP.md),
  with v0.4 steps 1-4 in full only for a repo with a unit folder, a main
  folder not clean or off its Base, or the first step's repo. The brief
  (`**shop · 3 repos**`, at most 25 lines) has a row per repo, its Current
  work plus ` · lands after <r2> <v>` while its record has not landed,
  then the Setup, Will move and Read by mistake rows. The first step is
  init's rules 1-7 over every repo, the lowest rule first, a tie by land
  order, rule 7 (`run aegonex-plan`) once; a consumer waiting on its
  record reads rule 6 as `when <r2> <v> has landed, run aegonex-done (a
  task may start meanwhile)`. A focus spanning repos is a cross-repo task.
  One question; a Base or Remote to ask names its repo, and only the first
  such repo asks.
- init's go sets up every ready repo: where setup is due (v0.4 setup plus
  the Repos section, or the section alone), the main folder is clean and on
  its Base (or will be after the move) and no question is needed, one
  `chore: aegonex setup` commit each, named in a Setup row. A repo left
  unset would stop every parent plan that touches it, and the section
  carries the land gate a repo session needs. Move, update and open run
  only in the first step's repos, in land order. The reply: `**Opened:**
  backend/.worktrees/t-discount, frontend/.worktrees/t-discount`, then one
  line of clauses led by `<r>: `.
- note (section 8) writes a line in each repo the fact concerns: `Noted
  (<kind>) in backend, frontend: <text>`. exit (section 9) runs its steps
  1-8 for each repo the session worked in, with one brief and a commit per
  repo (`backend a1b2c3d · frontend e4f5a6b`). Its push what I have goes
  in land order with the landed check run before the brief, so a consumer
  not landed reads `committed, not pushed: lands after <r> <v>`; a
  provider task that a sibling's record names is kept, never offered for
  Remove. plan and done: below.

(b) Opened inside one repo: `worktree list` succeeds, so this is v0.4,
plus what the Repos section and a record on the unit in play add: init's
`Lands after` row, done's one-line stop for routes 3 and 4, the task land
question stopped by the Repos section (`Not yet: stop, name it`) and
exit's push what I have stopped by its step 9. The check reads the sibling
at `<main>/../<r>` with at most two git reads and its AGENTS.md. Work that also
needs a sibling (the agent's call) opens nothing: the Repos section sends
it to the parent folder, which opens and links both halves. A repo session
writes no record. A repo never set up from `<P>` has no Repos section and
stays v0.4, so its half can land first.

(c) One session per repo, in parallel: each is (b) and writes only its own
repo. The record sits in the consumer; the provider's session never needs
it and lands when its checks pass, while the consumer's done waits for the
check. Usual flow: plan the feature once from `<P>`, then open one session
per repo. A feature started straight in two repo sessions meets the
sibling rule in the consumer's session, so no half lands unlinked.

### A feature across repos

The provider lands first: the repo whose API the others call (for a
removal, the caller). That is the agent's call, a Decision marked
`(agent's call)` (a task: its Note), shown in the plan brief and the land
question; the user may change it.

A cross-repo task (section 7) opens on init's go or when the leader starts
it, in each repo in land order, with that repo's **Open**; a repo without
the Repos section stops it first: `<r>: run aegonex-init <r> first`. note
then writes each repo's `t-<slug> done when:` and each consumer's record.
A parent request is one ROADMAP step or one cross-repo task, as
`repos.md` says. A part never spans repos: each repo is at least one part,
2-5 parts in all, dispatched at once in `<P>/<r>/.worktrees/<u>--p<k>`.
Review lines lead with the repo (`frontend p1: PASS: ...`), and a PASS
integrates into that repo's `aegonex/<u>`.

Landing it is the one chained go. When every repo's last part is
integrated, a unit folder whose status lists HANDOFF.md ends the report
with `run aegonex-exit first: HANDOFF.md in <r>/.worktrees/<u> has notes
not saved` (the v0.4.1 rule); else one land question in land order:
`Land? backend, then frontend: push aegonex/t-discount to main, remove
backend/.worktrees/t-discount, frontend/.worktrees/t-discount and their
aegonex/t-discount: Not yet / go`. The go, per repo in order: the landed
check, always run (a provider cleaned up earlier on this go passes);
**Sync** as `aegonex-done` step 2 says, so a unit opened before the
Repos-section commit carries it and a moved Base is merged; the check
again, since Sync may bring a record in; **Land**; **Clean up**;
`cd "<P>"` (dropped in v0.5.1). A repo that does not finish Clean up
stops the repos after it, which stay as they were. The reply is a line
per repo in the v0.4 form, led by the repo, then `Next:`. Asked to, the
leader lands alone the repos whose parts are all integrated; a consumer
among them still needs its check.

A milestone pair closes with `aegonex-done`, one unit per run, v0.4
unchanged per repo, so every stop stays a plain v0.4 state (section 10).
The consumer's done stops at step 1 (routes 3 and 4) until the provider
has landed; after the provider's Clean up, the `Next` row names the
consumer's next step (`aegonex-done for frontend m5`). Routes 1 and 2
(merged, waiting) are never blocked. A unit name that several repos share
picks the first in land order whose records have landed, else one question
naming `<r> <u>`.

Partial failure: every stop leaves each repo in a v0.4 state plus the
consumer's record, so init or done, from `<P>` or either repo, resumes it.

| Case | This go | The next call |
|---|---|---|
| task go, provider refused as protected | provider: branch pushed, pull request, folder kept; consumer untouched (`frontend: not landed: lands after backend t-discount`) | provider's done step 8 on "merged" (a task has no close commit, so v0.4 asks Remove / Keep), then `Next` names the consumer's land |
| task go, provider Sync stop, `[rejected]`, a key or an error | v0.4 stop line for the provider; consumer untouched | the land question again, after the named fix |
| task go, provider landed, its Clean up refused | its files named; its branch stays, so the consumer does not start | `aegonex-done` for the provider (route 4), then the consumer's land |
| task go, consumer refused after the provider landed | provider landed and removed; consumer takes v0.4's pull-request or `[rejected]` route | v0.4 |
| milestone, provider went to a pull request | provider's folder kept (v0.4) | consumer's done stops until the provider's step 8 removes `aegonex/m<k>` |
| provider landed unfinished by exit, Keep | its branch stays: not landed | consumer waits |
| the session dies mid-go | each repo in a v0.4 state | init shows it, done resumes it; no progress file |
| a record names a missing repo, or two units wait on each other | `<u>: after: <r> <v> cannot be checked: <reason>` | fixed by hand or through a parent plan |

Clean up stays per repo, never waiting for another; `<P>` needs none.

### Plans and the link

The record (section 2) sits only in the consumer:
- a milestone's on its ROADMAP.md line, before `done when:` (a check, so
  nothing follows it): `- [ ] M5 — cart page · after: backend m3 · done
  when: ...`, written by a parent plan in its `docs: plan M<n>` commit and
  retired by done's collapse;
- a task's as its own HANDOFF.md line `t-<slug> after: <r> <v>`, not a
  suffix on `t-<slug> done when:`, which done step 3 runs as a command. A
  parent note writes it while the provider's branch exists; exit carries
  it as a Note like the done-when line.

Never a cycle. In a repo with the Repos section, milestone numbers never
change once written (v0.4 plan may restructure unticked milestones, which
would break a sibling's record).

The landed check (section 3; read only, one command per call; `<S>` =
`<P>/<r>`, where a session inside one repo takes `<P>` as the folder
holding `<main>`):

```
git -C "<S>" rev-parse --verify -q refs/heads/aegonex/<v>      # prints a sha: not landed; for a task, no sha is landed
git -C "<S>" grep -q -E "^- \[x\] M<k> .* closed [0-9]{4}-[0-9]{2}-[0-9]{2}" <SB> -- ROADMAP.md   # m<k>: exit 0 = landed
```

`<SB>` is `<remote>/<Base>` from `<S>/AGENTS.md` (no remote: `<Base>`).
The pattern is ASCII (a PowerShell code page cannot break it), anchored
at the start only, so a line saved with CRLF still matches, and `M3 `
never matches `M30`. No fetch is needed: a unit branch goes only
in the provider's own Clean up, after its push or step 8's fetch updated
that ref. A task counts as landed once its branch is gone, since only
Clean up removes one, and its record is written only while the branch
exists. A milestone needs both facts, so a hand-edited `[x]` line does not
pass. No `<S>`, a git error or a cycle: stop, `<u>: after: <r> <v> cannot
be checked: <reason>`. Callers rerun it after Sync, which may bring a
record in, before **Land**.

No two sessions write the same file: state files are written only in a
repo's open milestone folder, by the one session working there; records
sit in the consumer; siblings are only read; git's `worktree add` stops a
second session opening the same unit.

Plan in the parent (section 6): the repos and the land order come from the
user's words, else the agent's call. It stops, a line per repo and nothing
written, on a touched repo's plan stop, a touched repo without the Repos
section, a cycle, or an open folder whose status lists ROADMAP.md (`<r>:
ROADMAP.md in .worktrees/m<n> has changes not committed; another session
may be writing it`). One milestone per touched repo: an open, unticked one
gets the feature as a later milestone line, else a new `m<n>`; each step
belongs to one repo; at most 7 steps per milestone and 7 questions in all.
The brief is plan's, with each ROADMAP.md named in the title, `Done when:`
per repo, a `Repo` column and a `Lands after` row (`frontend M5 after
backend M3`). The go commits `docs: plan M<n>` per repo in land order and
replies in at most 3 lines.

### Skill and AGENTS.md changes

- All five skills: `version: "0.5.0"`; the `worktree list` line runs on
  `<here>`, the folder the session opened in (was `<current folder>`;
  removed since: the shell's folder), and
  a pointer, a plain sentence at that step, says: `not a git repository`
  there, read `../aegonex-init/references/repos.md` (init:
  `references/repos.md`) and follow it.
- Lines printed only in parent mode live in `repos.md`; lines a repo
  session prints (init's `Lands after` row, done's stop, exit's step 9
  gate) stay in the SKILL.md files.
- `repos.md` opens with the calling skill's rules and "nothing is ever
  written in `<P>`", then has 11 sections: 1 Find the repos, 2 Records,
  3 The landed check, 4 Sessions, 5 Init in the parent, 6 Plan in the
  parent, 7 Leader mode across repos, 8 Note, 9 Exit, 10 Done, 11 The
  Repos section.
- The Repos section is `assets/AGENTS-repos.md`, which setup appends when
  its heading is missing, in the same `chore: aegonex setup` commit:

```
## Repos (aegonex 0.5)
- **Parent:** the folder above holds the project's other repos and is never a repo: no `git init`, file or commit there.
  Units, state files, commands and go stay per repo; one session per repo at a time; milestone numbers never change.
  A session inside one repo changes only that repo; work that also needs another repo starts in the parent folder.
- **After:** `after: <repo> <v>` on a unit's ROADMAP line, or `t-<slug> after: <repo> <v>` in HANDOFF.md (State files):
  it lands only once `<main>/../<repo>` has no `aegonex/<v>` branch and, for `m<k>`, `<remote>/<Base>:ROADMAP.md` there has
  `- [x] M<k> ... closed`. Not yet: stop, name it; git only reads there. The parent lands providers first; a refusal stops.
```

Measured: 22, 120, 116, 114, 119, 123, 123 bytes. It gives an agent
without the skills, and a repo session after compaction, the rules that
matter at landing (the task land question is an AGENTS.md procedure no
skill wraps) and the sibling rule. `(State files)` points at the HANDOFF.md
that the AGENTS.md bullet of that name picks, where a task record sits.

`assets/AGENTS.md` does not change: its two sections stay 43 lines under
`(aegonex 0.4)` headings, since init decides that setup is due from them
and a `0.5` heading would re-run setup in every existing project. A repo
of a multi-repo project carries 43 + 7 aegonex lines. (v0.5.1 rewrote the
Commands, Open and Clean up bullets in place: still 43 lines, the same
headings.)

Line budget (`wc -l`), raised by owner decision 1:

| File | v0.4.1 | v0.5 | Added | Cap |
|---|---|---|---|---|
| init | 318 | 323 | 2 pointer, 2 nested-repo guard, 1 row | 323 |
| plan | 224 | 225 | 1 pointer | 225 |
| note | 136 | 137 | 1 pointer | 137 |
| exit | 349 | 352 | 1 pointer, 2 in step 9 | 352 |
| done | 373 | 378 | 1 pointer, 3 gated stop, 1 in 7.4.2 | 378 (largest-file limit 380 holds) |
| total | 1,400 | 1,415 | 15 | 1,415 |
| `references/repos.md` | new | 100 | | 100 |
| `assets/AGENTS-repos.md` | new | 7 | | 7 lines, each at most 125 bytes |

Every cap moves by what its file gains. Trimming 12 Quick reference,
Common mistakes and Never rows that repeat procedure (total 1,403) was
turned down: those rows help weaker models, and v0.4's fix rounds showed
that compressed rule text loses rules. `scaffold.md` goes 90 to 89 (the
`.worktrees/.gitignore` line, rewrapped); `pull-request.md` (56/70) does
not change.

### Unchanged for single-repo projects

A session in a repo with no Repos section and no record behaves as v0.4.1:
the same commands, reads, briefs, questions, go actions, replies and stop
lines; `repos.md` is never read; no command reaches outside the repo.
done's record check and the Repos half of 7.4.2 (only that heading not
online: Clean up goes on with `-D`) are gated on the Repos heading. The one addition is init's nested-repo guard: one extra read when
the main folder's status lists an untracked folder, and a stop when that
folder is a repo root (Risk 11). `assets/AGENTS.md`, `assets/CLAUDE.md`,
`assets/ROADMAP.md`, `assets/HANDOFF.md` and `pull-request.md` are
byte-identical; `scaffold.md` only says outright that setup never adds
`.worktrees/.gitignore` (it ignores itself; never `add -f`); `tests/lifecycle.sh` (134 checks
since v0.4.1) does not change. v0.5.1 changes one thing in every project:
an install, a test, a done-when and Clean up's remove run as
`cd "<folder>" && <command>`.

### Left out of v0.5

- Any file or state in `<P>` (AGENTS.md, a feature id, a lock, a progress
  file); a record written from a repo session; a provider-side view of
  who waits for it.
- One go that closes a feature's milestones in several repos; a ROADMAP
  step spanning repos; parallel milestone work from one parent session.
- Fetching a sibling; testing the consumer against the provider's unit;
  deploy order; detecting two sessions in one repo.
- Repos deeper than one level, submodules, a monorepo with several test
  lines, a parent inside an outer repo, more than 6 repos; closing the
  task hole of Risk 1; moving uncommitted work between repos.

### Risks

1. A removed task branch counts as landed: a provider task landed
   unfinished by exit and then removed in a repo session, or deleted by
   hand, lets the consumer land against half an API. The parent exit never
   offers Remove for a provider that a record names (decision 6).
2. A task record lives in a HANDOFF line; an exit that drops it (the
   60-line trim) removes the gate, as v0.4 can drop a done-when line.
3. The v0.4 defect found while designing this (a task folder with unsaved
   notes refuses Clean up after the push) is fixed by v0.4.1. Projects set
   up with v0.4 keep the old Go bullet; the parent's chained land reads
   each folder's status itself.
4. A unit opened before the Repos-section commit lacks it: a task landed
   from a repo session (v0.4's Land has no Sync) stops at Clean up's
   `merge --ff-only`, and `aegonex-done` finishes it: 7.4.2 finds only the
   Repos section not online, so Clean up goes on and deletes the branch
   with `-D`; `<main>` keeps the commit and the next unit opened from
   `<Base>` carries it. The chained land Syncs first.
5. Two sessions in one repo can overwrite one HANDOFF.md or ROADMAP.md;
   only the written rule and the uncommitted-ROADMAP stop protect it
   (decision 8). Git refuses racing pushes and worktree adds.
6. Shell drift: holding `<P>`, and `cd "<P>"` after each `cd`, are new
   wording that weaker models may skip. (v0.5.1: a command that needs a
   folder names it, `cd "<folder>" && <command>`, so drift no longer runs
   a test in the wrong folder, and `cd "<P>"` is dropped: the agents
   skipped it in every parent session.)
7. Cost: a parent init is about 5 calls per quiet repo and 12-15 per busy
   one; a 5-repo brief is near the 25-line limit.
8. A breaking provider change landed first breaks the old consumer on
   Base; the plan brief and the land question show the order (decision 4).
9. A protected provider holds its consumers until a human merges; their
   folders live longer and Base drifts more (Sync handles it).
10. `repos.md` and the Repos section sit in aegonex-init; installing a
    subset of the skills breaks the pointers.
11. The nested-repo guard stops a project that keeps an untracked nested
    clone at its top level; the line says why, and `.gitignore` fixes it.
12. "Never `git init` in `<P>`" is a written rule (decision 5): an agent
    that runs no aegonex skill sees it only in a repo's AGENTS.md, and the
    guard catches a fresh `git init` on the next init, not a committed one.
13. The sibling rule rests on the agent's judgement of "needs another
    repo"; a half that looks self-contained can still land first unlinked.
14. A shell that goes back to its start folder on every call (some
    harnesses) cannot run v0.4's `cd "<f>"`, then the command, as two
    calls; agents chain them with `&&` (scenario M1, rounds 1 and 4). A v0.4
    rule; left for a later version. Resolved by v0.5.1: one chain form,
    `cd "<absolute folder>" && <command>`, for an install, a test, a
    done-when and Clean up's remove.

### Tests

Fixture: `tests/fixtures/make-multi-fixture.sh <dir> [--protected <r>]
[--repos <n>] [--ticked] [--no-milestones] [--no-repos-section]
[--git-init-parent]` builds `<dir>/shop/`, a plain folder: backend and
frontend set up with the v0.4 sections and the Repos section, backend with
`m3` open (2 of 3 steps ticked; `--ticked`: all), frontend with `m5` open
(every step ticked, `after: backend m3`), each ticked step's code committed
in its unit folder (`node --test` passes in both), admin with one commit and no
setup, and `docs/` and `notes.txt`. Bare remotes in `<dir>/remotes/` log
each push to `<dir>/push-order.log`. `--no-milestones`: no unit folders;
`--no-repos-section`: no Repos section; `--protected <r>`: `<r>`'s remote
refuses pushes to main, its hook installed after the fixture's own pushes;
`--repos <n>`: extra plain repos up to `<n>`; `--git-init-parent`: shop
itself is `git init`-ed.

Lab: `tests/multi-repo.sh`, where every git line is a command of
`repos.md` or of the v0.4 recipes it runs per repo. 37 checks in eight
groups, all passing: finding the repos (6: the parent's `worktree list`
fails; plain folders, linked worktrees and subfolders are not repos); the
landed check (8: closed, pushed, cleaned up; `M3` against `M30`; a task
with no branch); a squash-merged pull request (3); a cross-repo task whose
provider push is refused, then the push order, backend before frontend
(6); the Repos-section commit and done 7.4.2 (5: a unit opened before it
stops at `merge --ff-only`, the unpushed section is not reset away and
Clean up goes on with `-D`; the next unit carries the commit and lands
it); the nested-repo guard (2); a noted HANDOFF.md, committed by exit,
then landed (2); the review fixes (5: a CRLF closed line reads landed,
`M3` still misses `M30` without `$`, a frontend session finds backend as
`<main>/../backend`, and a record brought in by Sync stops the rerun
check).

Planned agent scenarios (Sonnet, one turn per message). Every turn
snapshots each repo and asserts that `shop/.git` is absent; no trace holds
`git init`, `clone`, `--force`, `reset --hard`, `stash` or `&&` (v0.5.1:
but `cd "<folder>" && <command>` for an install, a test, a done-when or
Clean up's remove).
- M1 parent init "เริ่มงาน" (`--no-repos-section`): a row per repo,
  frontend `land หลัง backend M3`, a Setup row naming admin (full setup)
  and backend and frontend (the Repos section), first step backend M3
  step 3; the go sets up every ready repo. M1b `--no-milestones`: `run aegonex-plan` once.
- M2 parent plan of a coupon across backend and frontend: a Repo column, a
  `land หลัง` row, the consumer's line with `after:`. M2b: an uncommitted
  ROADMAP.md stops it.
- M3 cross-repo task: parts dispatched at once, the record in frontend,
  the land question backend first, push order backend then frontend. M3b:
  the exit-first line. M3c: backend landed alone.
- M4 M3, and M5 the milestone pair (`--ticked`), with `--protected
  backend`: backend's pull request holds frontend until step 8.
- M6 a frontend session closing M5 while backend m3 is open: the stop line
  and at most two git reads of backend. M6b: the sibling rule. M7 a task
  land in a frontend session, stopped by the Repos section.
- M8 parent exit across both repos, also with the shell left in a unit
  folder and with push what I have. M9 parent note to one repo and to both.
- M10 a parent plan and a frontend session racing for one `m<n>`. M11
  parallel sessions in backend and frontend. M12 the stops: `--repos 7`,
  no repo, a missing repo, a cycle, `--git-init-parent`.
- M13 single-repo regression: V1-V11 unchanged, `repos.md` never read.

The judge gains multi-repo variants of `init-go` and `after-go`; the
parent brief keeps the 25-line limit.

### Owner decisions (2026-09-27)

All 11 accepted as recommended:
1. Raise the caps: SKILL.md total 1,415 (init 323, plan 225, note 137,
   exit 352, done 378); `repos.md` at most 100 lines; the Repos section 7
   lines.
2. A feature's milestones close one repo per `aegonex-done` run, provider
   first; the `Next` row names the other.
3. `after:` records are written only by a session opened in the parent
   folder.
4. The land order is the agent's call, shown in the brief as a Decision,
   which the user may change.
5. Nothing is ever written in the parent folder.
6. A task counts as landed once its branch is gone; the hole of a provider
   task pushed unfinished and removed from a repo session is accepted for
   v0.5.
7. Parallel work on a feature's milestones means one session per repo; the
   parent session does one step at a time (a cross-repo task still runs its
   repos' parts at once).
8. The one-session-per-repo rule is written only, no lock file.
9. The parent init's go sets up every ready repo (clean main folder on its
   Base, no question needed), not only the first step's.
10. The v0.4 defect found while designing this was fixed first, as v0.4.1
    (the exit-first rule, below).
11. A session inside one repo sends work that also needs another repo to
    the parent folder.

### Implementation (2026-09-27)

- The procedure lives in one reference file,
  `skills/aegonex-init/references/repos.md` (100 lines, sections 1-11;
  v0.5.1: 99, without `cd "<P>"`).
  Every skill points to it with one line when its `worktree list` fails
  with `not a git repository` (init's takes two, with "never `git init` or
  write anything in `<here>`"); single-repo projects never read it.
- The Repos section is its own asset file, `assets/AGENTS-repos.md`, that
  setup appends; `repos.md` section 11 says so in one line. This changes
  the draft, which kept that text inside `repos.md`.
- Line counts and what each skill gained:
  - init 323: the pointer, the nested-repo guard, the `Lands after` row,
    and "a folder that holds several git repos" in the description.
  - plan 225: the pointer.
  - note 137: the pointer; the red flag "one fact in one file".
  - exit 352: the pointer, step 9's push gate, `after:` lines kept and
    carried as Notes, and the one `ls` that `repos.md` names.
  - done 378: the pointer, step 1's stop on a record not landed (gated on
    the Repos heading), and the Repos heading in 7.4.2's online test: when
    it alone is not online, Clean up goes on with `-D`.
  - total 1,415.
- The v0.4 sections of `assets/AGENTS.md` are unchanged at 43 lines
  (v0.5.1: Commands, Open and Clean up rewritten in place, still 43).
- `tests/multi-repo.sh` passes 37 of 37 and `tests/lifecycle.sh` 134 of
  134; the agent scenario results are in `docs/testing.md`.
- A review round (22 confirmed findings) and the first scenario round
  changed: `ls -pL`; the landed check without `$`, at `<main>/../<r>`
  from a repo session, rerun after Sync and always run on the land go;
  Setup rows for a missing Repos section; 7.4.2 going on with `-D`;
  `<here>` falling back to the shell's folder once removed; plan keeping
  every ` · after:` on a milestone line; exit never trimming a
  `t-<slug> after:` line; single-repo init reading `repos.md` only when
  step 1 or a record sends it there.
- The second scenario round changed: a parent plan takes the land order
  from the user's own words only, else writes it as an `(agent's call)`
  Decisions line in each touched ROADMAP.md; setup never force-adds
  `.worktrees/.gitignore`.
- The third round changed: init's step 2 table and Setup row say that, in
  a folder that holds repos, a missing `## Repos (aegonex 0.5)` heading
  also makes setup due, of that section alone when the rest is there (a
  repo set up with v0.4 gets only the section).

## v0.4.1 (2026-09-27): a task's notes are saved before it lands

The defect, found in a scratch lab while designing v0.5: with no open
milestone folder, `aegonex-note` writes into the task folder's own
`HANDOFF.md` (its `t-<slug> done when:` line at the least) and commits
nothing. The land question's go then pushes, and Clean up's
`worktree remove` refuses the folder, because it holds uncommitted
changes. Nothing is lost, but the go stops half done: landed on Base, the
folder and branch left behind, and the next `aegonex-done` goes the long
way (exit, then every check, a `chore: close` commit and a second push).

The fix, the rule `aegonex-done` step 1 already has for routes 3 and 4:
- `AGENTS.md`, **Go**: a task due to Land ends its report with the land
  question, or, while `<f>`'s status lists `HANDOFF.md`,
  `run aegonex-exit first: HANDOFF.md has notes not saved` (one more
  line: the two sections are 43 lines; compressing the bullet in place
  would have cut other rules, the reason v0.4's fix rounds give).
- `aegonex-exit`, after its commit: a task whose last part is integrated
  gets the land question as the reply's last line, so saving the notes
  and landing cost two goes, not three turns.
- The five skills are `0.4.1`; the section headings stay
  `(aegonex 0.4)`, since `aegonex-init` decides that setup is due from
  them.

Projects set up with v0.4 keep their copy of the sections: setup only
appends sections that are missing. There the old behaviour stays; saying
`aegonex-exit` before the land go avoids it.

## v0.4 spec (2026-09-26): one folder per piece of work

Why: until v0.3 the agent worked on whatever branch the main checkout was
on. It edited next to the user's own work, left branches behind and could
not split big work. The owner's requirements, binding:
- R1. All work, a plan included, happens in a git worktree on its own
  branch, never in the main checkout. It merges into Base only when all of
  it is done, and merge and push run only on a go that names them.
- R2. The agent leads: small work is one part; big work is split into parts
  written by parallel subagents in their own worktrees. A separate reviewer
  checks every part, even a one-part typo fix. Without subagents the review
  is marked `review not independent`. Every agent reads this in AGENTS.md.
- R3. After landing, the folder and branch are removed on the same go.
  Landed while unfinished: ask Remove / Keep, no answer is Keep. Never
  force-remove uncommitted or unpushed work. Protected Base: push the
  branch, open a pull request, keep the folder until it is merged.

Scope (owner): the small version. One machine; no online-only units, no
notes file, no landing proofs. A rare case that would need machinery is a
plain stop row with one command.

Unchanged from v0.3: the reply format, the language rule (the reply and
every line a skill writes follow the user's message, whatever language an
old file is in; a message with no language of its own, the skill's name or
a bare `go`, `ok`, `yes`, takes the conversation's so far), who writes
which file, and "nothing is written before go", with v0.3's two
exceptions: note appends its line at once, and exit
writes HANDOFF.md, ROADMAP.md ticks and anchor lines in the state folder
before its question, so the go only commits (and, for "push what I have",
syncs, scans and lands).

### Names

| Thing | Name | Folder | Branch |
|---|---|---|---|
| main checkout | `<main>`: first `worktree ` path of `git worktree list --porcelain` | stays on Base | Base |
| milestone M<n> | `m<n>` (no slug) | `<main>/.worktrees/m<n>` | `aegonex/m<n>` |
| work outside the roadmap, a typo included | `t-<slug>`, 1-3 English words in `a-z0-9-`; `t-<slug>-2` when an old pull request holds the name; work moved from a branch `<b>` takes `<b>` after its last `/` (`fix/db-race` → `t-db-race`) | `<main>/.worktrees/t-<slug>` | `aegonex/t-<slug>` |
| part k of a unit | `<u>--p<k>` | `<root>/.worktrees/<u>--p<k>`; `<root>` is the harness folder when the unit lives in one, else `<main>` | `aegonex/<u>--p<k>` |
| harness-made worktree, detached or on a branch outside `aegonex/*` | the unit it holds | adopted as is | `switch -c aegonex/<u> <Base>`; the harness's branch stays |

- `<main>/.worktrees/.gitignore` holds `*` (it hides itself too). The
  project's `.gitignore` is untouched; an existing `.dockerignore` gets the
  line `.worktrees` on the setup go. Both are checked with `ls -a
  "<main>"`, then, if it lists `.worktrees`, `ls -a "<main>/.worktrees"`,
  one call each.
- `Base:` and `Remote:` are one line in AGENTS.md's Working mode section.
- **closed** `<u>`: `git -C "<f>" log -1 --first-parent --no-merges
  --format=%s` prints `chore: close <u>` (it survives a Sync merge).
- **online** `<u>`: `refs/remotes/<remote>/aegonex/<u>` has the same hash
  as `aegonex/<u>` (a stale copy from an old pull request is not online).
- **state folder**: the open `m<n>` folder that is not closed; else the
  task folder you work in; else `<main>`, read only. A closed `m<n>`
  waiting for its pull request is never written again.
- Status is always read as `git -C "<f>" -c core.quotePath=false status
  --short`, so a Thai path goes back to git as printed.

### Rules

1. ROADMAP.md and HANDOFF.md are edited only in the open, not closed
   milestone folder. A task never edits ROADMAP.md and edits HANDOFF.md
   only when no such folder is open.
2. Only the setup commit is made in `<main>`; everything else commits on
   `aegonex/*`. Opening, editing, checks, commits, Sync merges and part
   integration need no go beyond the request; landing, pushing, a pull
   request and removing a unit folder or branch need a go to a reply that
   names them: the push to Base, the folder `.worktrees/<u>` and the branch
   `aegonex/<u>`, all removed on that same go. Silence, a timeout, an
   autopilot answer or a go to another reply is no, and every landing or
   removal question lists the safe answer first. A task due to Land (its
   last part integrated) ends its report with the land question
   `Land? push to <Base>, remove .worktrees/<u>, aegonex/<u>: Not yet /
   go` (Thai `ยังไม่ land`); v0.4.1: while its folder's status lists
   `HANDOFF.md`, `run aegonex-exit first` in its place. After landing, the reply is at most
   3 plain lines, no outer code span, no table and no question (only the
   sha, branch names, paths, skill names and commands in backticks):
   `<sha> · landed on <Base> · .worktrees/<u> removed`, then
   `Next: <next step>`.
3. Every command, read-only ones (`pwd`, `ls`, `git status`) too, is one
   line and one tool call, no `&&`, `||` or `;`, so PowerShell 5.1, cmd and
   dash all run them (dates: `Get-Date -Format yyyy-MM-dd`; greps: `git
   grep`; no `wc`). An exit code is read from the tool result (no error
   shown = 0), never with `; echo $?` or `|| true`. Git is always
   `git -C "<absolute folder>" ...`, even when the shell (or a harness
   prefix) already stands in that folder, after a go too; no `cd` to run a
   read. The install runs as `cd "<f>"` on its own call, then the install
   command on its own call (lifecycle 3). v0.5.1: an install, a test and a
   done-when run as one call, `cd "<absolute folder>" && <command>`, and
   Clean up's remove as `cd "<main>" && git -C "<main>" worktree remove
   "<f>"`: the only chains, since a shell may not keep a `cd` between calls.
4. Never `--force`, `--no-verify`, `reset --hard`, `stash`, `add -A`; never
   delete an online branch; `branch -D` only after the pushed check.
5. Nothing moves `<main>`'s branch unless `<main>` is on `<Base>`.
6. No new milestone while a milestone waits for its pull request.

### AGENTS.md: two sections, 42 lines together (43 from v0.4.1)

`assets/AGENTS.md` ends with `## Working mode (aegonex 0.4)` (Unit,
Commands, Open, State files, Go, Land, Clean up, Never) and
`## Leader mode (aegonex 0.4)` (Size, Part folders, Dispatch, Review,
Integrate); the verbatim text is in that template. `CLAUDE.md` is
`@AGENTS.md` plus one sentence; Codex, Cursor, OpenCode and Copilot read
AGENTS.md natively. The sections carry commands, so an agent without the
skills opens the right folder, reviews every part and stops at the same
boundary. Skills cite them by bold name instead of repeating them. They
are exactly 42 lines, each at most 125 characters: any later edit is made
in place.

### The lifecycle, with the commands (each proved in the lab walk)

1. **Setup** (init's go, `references/scaffold.md`): Remote = the one name
   `git remote` prints, else `origin`, else one question (several), else
   none. Base = `symbolic-ref --short refs/remotes/<remote>/HEAD` minus the
   prefix, else `main` when `refs/heads/main` exists, else `master`
   likewise, else ask; the current branch is never the fallback. A value
   that must be asked is the brief's one question (a `?` row, the question
   in place of the go line; the answer counts as the go). The brief's
   `Setup` row names Base, Remote and every file the go writes. Write or
   append the sections, `@AGENTS.md`, `.worktrees/.gitignore`; `add --
   <files>`, `commit -m "chore: aegonex setup" -- <files>` (unborn: plus
   the top-level entries, never `.env*` or dependency folders). No install
   line in AGENTS.md: derive it from the manifest (`package.json` → `npm
   install`, `pnpm-lock.yaml`, `yarn.lock`, `pyproject.toml`,
   `requirements.txt`, `go.mod`, `Cargo.toml`), else `none`.
2. **Init's go order**: move (save the changes to a patch, `restore`,
   `switch <Base>`, `<b>` kept), then **Update** when `<Base>..<remote>/<Base>`
   lists a commit, then setup, then Open the unit (moved work:
   `t-<slug>`). The move recipe's step 7 opens it: `worktree prune`; a new
   unit `worktree add -b aegonex/<u> "<main>/.worktrees/<u>" <b>` (no
   `<b>`: `<Base>`; `aegonex/<u>` already there, `<b>` itself or a
   leftover: `worktree add "<main>/.worktrees/<u>" aegonex/<u>`, reused);
   a new unit not made from `<Base>` then runs `merge --no-edit <Base>`, so
   it carries the setup commit and the v0.4 sections (a conflict: `merge
   --abort`, named in the reply, go on); a unit whose folder exists runs
   `merge --no-edit <b>` (with a `<b>`). After that merge, step 8 runs
   `apply --3way` with the patch and `restore --staged -- <files>`
   (because `--3way` stages what it applies); step 9, only when step 7
   added the folder, is the install as in Open (`cd "<unit folder>"`, then
   the install command, each its own call, once; v0.5.1: one call, `cd
   "<unit folder>" && <install command>`); step 10 is `rm
   "<main>/.worktrees/move.patch"` (PowerShell `Remove-Item -LiteralPath`).
   Init's go runs the recipe's steps 1 to 5, then update and setup, then
   steps 7 to 10. Updating before setup keeps the setup commit on top of
   the current Base. From a harness folder, setup and move stop with
   `start a session in <main> and run aegonex-init`. The go's reply is at
   most 2 lines, no table or question: `**Opened:** .worktrees/<u>` /
   `**เปิดแล้ว:** .worktrees/<u>`, then one line of what the go did, one
   clause per action joined by ` · ` (`moved <files> (<b> kept)`, `updated
   the main folder`, `set up: <files>`, a failed or stopped action with its
   first error line quoted, and after a move `reopen your editor there`);
   then the step runs under Leader mode and its report follows. An inspect
   step reports, from `git -C "<f>" diff HEAD -- <files>` alone (an
   untracked file: its content), what changed and any `AIDEV-NOTE` in it,
   context lines included, never a guess at intent. Git stays `git -C`
   after the go; init's red flags name `The shell already stands in the
   folder, plain git is fine`.
3. **Open**: `worktree prune`, `worktree add "<main>/.worktrees/<u>"
   aegonex/<u>` if the branch exists, else `worktree add -b aegonex/<u>
   ... <Base>`; then `cd "<f>"` on its own call and the install command on
   its own call (v0.5.1: one call, `cd "<f>" && <install command>`; an
   install line of `none` is skipped). A failed install
   is quoted by its first error line as printed and the work goes on: no
   retry, no diagnosis, no command outside the project (never `sudo`). A
   new name whose `<remote>/aegonex/<u>` exists: a task takes `-2`; a
   milestone stops, `by hand: delete aegonex/m<n> on the host, then git -C
   "<main>" fetch --prune <remote>`.
4. **Plan**: step 2 asks only what the write condition (step 3) still
   needs, in the list's order; the list is never a checklist to complete.
   Before the first question and after each answer the milestone is
   composed from what is known and the write condition checked first;
   asking stops once it holds. Question 1 (`What should it let its users
   do?`) is asked only when the first message does not say who uses it
   and what it does; questions 4-6 (constraints, risk, order) come only
   when a step or its `done when` cannot be written without them. A
   detail a step needs that the user did not give (order, data source,
   stack, or a structure the user did not show, such as a route path or a
   menu) is the agent's call, written under Decisions with `(agent's
   call)`, never asked, and no step assumes one without that line. An
   answer of none (no deadline, no constraint) adds no Constraints line or
   row; the `Not doing` row gives a reason only when the user gave one. On
   go: Open `m<n>`, write ROADMAP.md, `commit -m "docs: plan M<n>" --
   ROADMAP.md`, then a reply of at most 3 lines of plain text (no outer
   code span) naming step 1 and its done-when, and stop: step 1 starts on
   the user's next message. A change that fits one step is a task: asked
   to plan it (or naming plan), plan writes nothing and it starts on the
   user's next message; asked to make it, the agent leads it at once
   under Leader mode, without plan. The brief's question is `Commit this
   plan?` (v0.3: `Start step 1?`). It stops while `m<n>` is closed: waiting
   (online) or `run aegonex-done` (not landed).
5. **Lead**: a request is one ROADMAP step or one task; after its last
   part is integrated the agent reports and stops (a task's report ends
   with the land question, rule 2). Size is judged by files, never by the
   subagent tools at hand: work that changes 2+ modules is 2-5 parts on
   different files, else one part in `<f>`; every part, a small one too,
   has a done-when (a command or fact showing it works). With subagents:
   commit the leader's files by name,
   `worktree add -b aegonex/<u>--p<k> "<root>/.worktrees/<u>--p<k>"
   aegonex/<u>` per part, writers commit there. Without them the parts run
   one at a time in `<f>`: edit, **Review**, commit on PASS before the next.
   **Review**: a fresh read-only subagent, not the writer (none: the agent
   itself), runs the done-when and reads `git -C "<p>" diff
   aegonex/<u>...HEAD` (`<p>` the part folder); for work in `<f>`, before
   the commit, `git -C "<f>" status --short`, `git -C "<f>" diff HEAD` and
   every new file. The reply has one line per part, `PASS: <done-when>,
   diff: <files>` or `FAIL: <why>` (unsure: FAIL), so a skipped
   read shows; a line the agent reviewed itself ends `(review not
   independent)`, as is. Only a PASS is integrated
   (work in `<f>` committed by name; a part: `merge --no-ff`, `worktree
   remove`, `branch -d`; no go). A redo first merges `aegonex/<u>` into
   the part. The state files a skill writes are not parts and need no
   review. Uncommitted work is never removed, the agent's own included;
   work outside the request is named in the reply, not undone.
6. **Note**: one line appended to the state folder's HANDOFF.md (under its
   section heading, added when missing), at most 120 characters judged by
   eye (no tool counts them), never committed; checked afterwards with
   `git grep -i -E --untracked`. A decision's why is written only when the
   user or the session gave one, never invented. To fit, the words that
   repeat the kind go first (`didn't work`, `failed`, `ไม่เวิร์ค`), then
   the why is shortened; a word naming what was tried or decided is never
   cut, and the user's own words for it are kept.
7. **Exit**: rewrite HANDOFF.md in the state folder (its Branch and HEAD)
   from `assets/HANDOFF.md`, read by its path beside SKILL.md (never `ls`
   or `find`, on the project or the skill folder), tick steps (never the
   milestone line), all before the question; commit on go. A step whose
   `done when` names a command or test is ticked only when that command
   ran here and passed (a commit alone is not enough); a file or decision
   it names: the commit that made it. Every line exit writes, HANDOFF.md
   and the new ROADMAP.md lines (Decisions, new steps), is in the reply's
   language, whatever language the file already uses; a number or name
   replaced inside an old line leaves the rest of it as it was. A
   decision's `(<why>)` is written only when the user or the session gave
   a reason, never a placeholder or an invented one. Stopped at has one
   line per file the status lists but HANDOFF.md and ROADMAP.md (init's
   Unrecorded work check leaves them out too): what changed, an untracked
   file only by what the session said about it; a file outside the action
   line adds `not committed, not part of the handoff commit` /
   `ยังไม่ commit (ไม่รวมใน commit handoff)`; with push what I have, one in
   it adds `committed unfinished, landed on <Base>`, written as done, never
   as staged or with will / จะ. Next step is one action, never two joined
   by `then`. A task as the state folder never touches ROADMAP.md: today's
   decisions become dated Notes `YYYY-MM-DD — <decision>[ (<why>)]`. While
   a closed `m<n>` waits for its pull request, the Current work row names
   the task and `M<n> closed, waits for its pull request`, the waiting
   folder's Dead ends and Notes are carried, and the last Note is
   `M<n> closed, waits for its pull request (aegonex/m<n>)`.
8. **Done**: step 1 runs whole and first on every call, a go or a
   merged-PR message included; nothing is carried over from an earlier
   turn. It stops on part branches `aegonex/<u>--p*`, on uncommitted files
   (a row naming them, `First step: commit <files>`, the question `Commit
   them now?`), or on `<main>` not on `<Base>`. Step 3 runs each distinct
   `done when` check once (a command several lines name counts once), the
   tests (once, `CI=true` plus the environment HANDOFF's Notes name;
   skipped as a repeat only when a check above is the same command line,
   else run and counted even when its script repeats checks) and the
   anchor grep even after one fails, and lists every failure. A `done
   when` that is a fact in a file (`recorded below`, `documented in
   <file>`) is read there, else `not in <file>`; a failure with no output
   takes its reason from the condition the check's own script tests, else
   `exit <code>, no output`. The cannot-close table lists only failing,
   then not-run, then TODO rows; a passed check is only in the count. A
   missing runner is `not run: <runner> missing`, never passed, and its
   first step is by hand when AGENTS.md has no install line. A go on a
   cannot-close brief runs its first step as one reviewed Leader-mode part
   in `<f>` (the failed check rerun, `status --short`, `diff HEAD`, every
   new file; committed on PASS; an install command is just run), then
   every check anew from step 3 after the first step and its commit, if
   any (the review's check too, never its earlier result), and a
   new brief with one line under its title, no sha, in place of
   **Review**'s `PASS:` or `FAIL:` line: after a committed fix
   `Fixed: <files> committed (review not independent)` /
   `แก้แล้ว: commit <files> (review not independent)`, after a FAIL
   `FAIL: <evidence> (review not independent)`, the parenthesis only
   without subagents and never translated; that go closes, lands and
   removes nothing. **Retire**: a decision goes only when nothing in the
   landed code still follows it; one the shipped behaviour embodies (a
   lifetime, a limit, a format, a library) stays; unsure: keep. A `Not
   doing` entry goes only when it names only this milestone. **Retro**:
   the dead end that would have saved the most time becomes one line
   under Rules in `<f>/AGENTS.md`, never `<main>`'s, in the close commit.
   **Sync**: `fetch <remote> <Base>`, merge `<remote>/<Base>`, then local
   `<Base>` only when `log <remote>/<Base>..<Base>` prints nothing or only
   `chore: aegonex setup`; the user's own unpushed commits stop the brief
   and are named. A HANDOFF.md conflict keeps this unit's copy plus the
   Dead ends, Notes and Session log lines of `show MERGE_HEAD:HANDOFF.md`
   it lacks. `merge --abort` only when `MERGE_HEAD` exists. Secret scan
   over `<remote>/<Base>..aegonex/<u>` (no `<remote>/<Base>`:
   `aegonex/<u>`); a scan that exits non-zero stops.
   The go: `git rm` the tracked candidates, `rm -- "<f>/<file>"` each
   untracked one on its own line (PowerShell `Remove-Item -LiteralPath`;
   never `-r` or `-f`), `<f>/ROADMAP.md` and `<f>/AGENTS.md` written and
   nothing in `<main>` (a file written, checked out or restored there is a
   red flag), `commit --allow-empty -m "chore: close <u>"`, Land, then
   **Clean up**: `cd "<main>"`, `merge-base --is-ancestor aegonex/<u>
   <remote>/<Base>`, **Update**, `worktree remove`, `branch -d` (v0.5.1: no
   `cd "<main>"` of its own; the remove is one call, `cd "<main>" && git -C
   "<main>" worktree remove "<f>"`). The reply
   is exactly the two plain lines of rule 2, the second the brief's `Next`
   row: ``Next: `aegonex-plan` for M3; type `/clear` first``.
9. **Update** (done Clean up 2, init): `<main>` on `<Base>`; `merge
   --ff-only <remote>/<Base>`; refused: `reset --keep <remote>/<Base>` only
   when `log <remote>/<Base>..<Base>` prints one or more lines, all `chore:
   aegonex setup`, and `git grep -q -F "## Working mode (aegonex 0.4)"
   <remote>/<Base> -- AGENTS.md` exits 0; else stop and name the commits.
10. **Protected Base** (done's `references/pull-request.md`, read at step
    7.3 and step 8): the whole push output holds `[remote rejected]`
    and `protected`, `GH006`, `GH013`, `pull request` or `review` → `push
    <remote> aegonex/<u>` (no `-u`; refused: stop, quoted). Only when
    `remote get-url <remote>` prints `https://<host>/<owner>/<repo>` or
    `git@<host>:<owner>/<repo>` (with or without `.git`): `gh pr create`
    when gh works, else the printed link, else
    `https://<host>/<owner>/<repo>/compare/<Base>...aegonex/<u>`. Any other
    URL (a path, `file://`): no gh and no link; the reply says `open a pull
    request for aegonex/<u> into <Base> on your host`. `<owner>/<repo>` is
    never guessed. The after-go reply is done's two lines, the first
    naming the ignored files after the folder: `a1b2c3d · pull request
    <link> · .worktrees/m2 kept until it merges (with .env)` /
    `(พร้อม .env)`, then the `Next:` line. When the user says it is merged
    (step 1 has run again): `rev-parse aegonex/<u>` equals `rev-parse
    --verify -q <remote>/aegonex/<u>` (missing: `fetch <remote> <Base>`;
    merged by ancestry → Clean up, else stop, `the online copy is gone`,
    the by-hand removal named), `fetch <remote> <Base>`. A closed unit then
    runs Clean up from Update with `branch -D` at once, no second question
    (its close go named the removal), and replies with the same two
    lines, the first `a1b2c3d · merged into main · .worktrees/m2 removed`;
    a unit landed unfinished by exit asks Remove / Keep, Keep first. The
    waiting brief (`Merged? Remove now?`, `Not yet` first) is printed only
    while the unit waits and the user has not said it is merged; it names
    the ignored files that go with the folder. A unit that is neither
    closed nor online gets one line, `no pull request was opened for it`,
    then the normal routes.
11. **Closed, not online**: already in `<remote>/<Base>` by ancestry →
    Clean up only; else Sync and `Will land`, with a row `if its pull
    request was merged, say merged instead`.
12. **Unfinished landing** (exit, "push what I have"): the question names
    commit, Sync, scan and the push to Base (no question tool: the last
    line is `Reply **go** to commit and push, or say no to leave it
    unpushed.`); on go, commit, Sync as done step 2, scan, Land (push
    output read as done; `[rejected]`: `Base moved: run aegonex-exit
    again`), then a reply of at most 4 lines of plain text, no title or
    table, only the sha, paths and branch names in backticks: `<sha>
    handoff committed · aegonex/<u> landed on <Base> (unfinished)`, `<sha>`
    the tip that landed (`rev-parse --short HEAD` after the push: the Sync
    merge when Sync made one, not the handoff commit), and Remove / Keep
    (Keep first, no answer is Keep), the ignored files after the folder:
    `(with .env)` / `(พร้อม .env)`. Remove is Clean up. On the pull-request
    path the reply gives the link or the `on your host` line, and nothing
    is asked until done step 8.
13. **Harness folder**: lands from itself; cleanup runs `switch --detach`
    and `branch -d` there, never removes the folder; the next init runs
    Update in `<main>`.

### Stop rows instead of machinery

| Case | The reply |
|---|---|
| a key in an unpushed commit, or a scan that failed | `a key is in <file> (commit <sha>)`; by hand: `reset --soft <remote>/<Base>`, take it out, commit |
| the host's push protection finds a key | `the host found a key in these commits` |
| Base moved between Sync and push (`[rejected]`) | the close stays; `run aegonex-done again` (exit's unfinished landing: `run aegonex-exit again`) |
| the branch push is refused | quote its `!` line and stop |
| the remote is not a host URL (a path, `file://`) | no `gh`, no compare link: `open a pull request for aegonex/<u> into <Base> on your host` |
| unit branch differs from its pull request copy | by hand: `git -C "<f>" push <remote> aegonex/<u>` |
| the online copy is gone (host deleted it, a prune fetch dropped it) | if merged, by hand: `worktree remove "<f>"`, then `branch -D aegonex/<u>` |
| `<main>` is on another branch | by hand: `git -C "<main>" switch <Base>` |
| `<main>` has commits that are not online | name them; Sync asks to land without them; Update stops |
| a milestone name held by an old online branch | by hand: delete it on the host, then `fetch --prune` |
| part branches `aegonex/<u>--p*` left | `<u> has parts not integrated: <branches>` |
| folder has modified or untracked files | `worktree remove` refuses; name them; never `--force` |
| remove fails part-way (Windows lock) | `worktree prune`, ask the user to delete the folder |
| a unit branch held by another folder | not adopted; the reply names the folder |
| a Sync conflict that cannot be resolved | `merge --abort` (when it started); the first step names the files |
| runner or dependencies missing | `not run: <runner> missing`; the install command is the first step, on go; no install line in AGENTS.md: by hand, install it and write the line |

### Skill changes (line counts after the agent-run fixes, `wc -l`)

| Skill | v0.3 | v0.4 | What changes |
|---|---|---|---|
| init | 251 | 318 | worktree facts, state folder, Work folder / Other work (waiting, leftovers) / Will move rows, main-folder checks, first-step order with the closed milestone rule, go order move → update → setup → open/adopt, reused task names, git grep anchors; after the agent runs: Base never the current branch, the Setup row, moved work into `t-<slug>`; fix round 2: the move's step 7 merges Base into the new unit, the two-line go reply; fix round 3: the install as the move's own step 9 (`cd`, then the command), the inspect report from the diff alone, the plain-`git` red flag; `references/scaffold.md` 90 lines, limit 90 |
| plan | 193 | 224 | reads the open milestone folder; stops (no sections, closed waiting or not landed, all ticked); composes before go, opens `m<n>` and commits only ROADMAP.md on go, then a three-line reply and stop; fix round 2: the write condition after every answer, missing details the agent's call; fix round 3: ask only what the write condition still needs, question 1 only when the first message lacks it, an unshown structure the agent's call, the plain-text on-go reply; fix round 4: a one-step change the user asked to make is led at once, not deferred |
| note | 115 | 136 | clock read, names-kept secret rule checked with `git grep`, the not-closed milestone folder, `Not saved` when no folder is open; fix round 2: 120 characters by eye, the why shortened first; fix round 3: a why only when given, the kind's repeated words cut first |
| exit | 302 | 348 | state folder, `-C` git facts (C26), carry and correct (C20), never ticks a milestone line (A1), `docs:` only for working documents (A3), `AIDEV-TODO(<unit>)` (C19), step 9 cites done's Sync, scan and push reading; HANDOFF in the reply's language, the waiting-milestone Current work row; fix round 2: every written line in the reply's language, a task's decisions and the waiting line as Notes, the plain-text unfinished-landing reply; fix round 3: the template read by its path, never `ls` or `find`, a why only when given, each Stopped at line's commit state, a command done-when ticked only on a run here |
| done | 216 | 373 | unit resolution, closed/online, stop checks, Sync with the local-Base guard, task checks, tests once (C22), install first (D7), scan, Land, Clean up with Update, HANDOFF never deleted (A2); every check runs, `not run: <runner> missing`; the pull-request path in `references/pull-request.md` (56 lines, limit 70); fix round 2: distinct checks, facts read from files, a table of failures only, a reviewed first step on go, Clean up at once when merged; fix round 3: step 1 first on a go too, the retro rule in `<f>/AGENTS.md` and nothing written in `<main>`, every check again after the reviewed fix under a `Fixed:` or `FAIL:` line, the two-line after-go reply with `Next:`; fix round 4: every check anew after the fix's commit |
| total | 1,077 | 1,399 | limit 1,400; largest file 373, limit 380; the AGENTS.md sections 42 lines, none over 125 characters (v0.4.1: exit 349, total 1,400, sections 43 lines) (v0.5: init 323, plan 225, note 137, exit 352, done 378, total 1,415; repos.md 100; Repos section 7 lines) (v0.5.1: the same) |

Duplication: 23 single lines appear in two or more skills, all of them
frontmatter keys, section headings, table header and template rows, the
two question lead-in lines (`The question comes last, ...`, `- Otherwise
the reply ends ...`) and the anchor `git grep` line; the longest shared
run is the 5-line frontmatter tail, so no shared block exceeds 10 lines.
Exit cites done for the secret pattern instead of repeating it. No new
file type: only `.worktrees/.gitignore` is new in a user's project.

### Known issues covered

- A1: exit never ticks a milestone line; only done's collapse closes one.
- A2: HANDOFF.md is never a deletion candidate; init skips a stale
  `aegonex-done` next step for a closed milestone.
- A3: exit lists on `docs:` only files called working, draft or temporary.
- B4: note's grep only finds candidates; names and placeholders stay,
  values and key-shaped strings become `<redacted>`, checked after writing.
- B5: note reads the clock once (`date '+%F %H:%M'` / `Get-Date`).
- C6: every anchor search is one `git -C "<f>" grep -n --untracked -E
  "AIDEV-(TODO|NOTE)" -- . ":(exclude,glob)**/AGENTS.md" ...` line.
- D7: done's description drops bare done / finished / เสร็จแล้ว; plan drops
  "what next"; done never installs; init names what it edits on the go.
- Kept round-2 fixes: C19, C20, C22, C26.

### Dropped from round 2

The notes file in the git dir; online-only units, backup push and machine
switching; landed proofs (merge-tree, first-parent) and git 2.38; Closed
elsewhere; Set aside and `aegonex-kept/*`; Leftover and Unfinished-rebase
machinery (a `UU` status is a plain first step; leftovers are one row);
the `## Open tasks` section; Catch up's three cases (one guarded Update);
headless reviewer commands and `references/harnesses.md`; the lead report
format; `GIT_TERMINAL_PROMPT`; the jest row; the identity lint.

### Testing

- `tests/lifecycle.sh` (bash, bare repos as remotes, a pre-receive hook as
  the protected Base, a `gh` stub): 130 checks. 1-20 walk setup, plan, a
  two-part lead, a task beside the milestone, exit, done, the protected
  path with squash and merge commits, `fetch.prune`, Keep and Remove,
  reopen, never-force, the HANDOFF conflict, moves, harness adoption, the
  setup-only reset, unborn, the scan, no remote, Base moving.
  `tests/review-round.sh` (21-36) replays each review finding with the
  fixed recipe: setup carried after a move, the reset guard, `<main>` on
  the user's branch, a reused task name and a refused branch push, a
  harness made before setup, an empty remote, exit's commit-then-Sync, a
  Thai path, `.env` while waiting, an unpushed Base commit, a pruned
  online copy, update before setup, the closed state folder, the adoption
  guard, a landed unit whose cleanup stopped, GH013, a leftover part.
  Green on git 2.54.
- `tests/judge.sh` keeps every v0.3 check and gains `init-go`, `after-go`,
  `keep-ask` and `done-wait` (`tests/samples/` holds one passing reply per
  kind), `Will land` / `Will remove` for done, and disk facts per
  worktree, the `aegonex/*` branches and the online refs.
- `tests/fixtures/make-v04-fixture.sh <fixture> <unit> [--protected]`.
- Agent scenarios, two turns each (brief, then `go`; V7 a third), Claude
  Code plus one Codex smoke run; no `--force`, `reset --hard`, `stash`,
  `--no-verify`, and an empty diff before go: V1 init on stale-app (move
  of `fix/db-race` into `t-db-race`, merged with Base so it carries the
  setup; the go reply, `init-go`: `**Opened:** .worktrees/t-db-race`, one
  ` · ` line ending `reopen your editor there`, then the step's report),
  V2 plan on fresh-app, V3 a two-module request, V4 note from a task
  folder while `m2` is open, V5 exit on session-end-app, V6 done
  unprotected, V7 done `--protected` (turn 2, `after-go`: `<sha> · pull
  request <link> · .worktrees/m2 kept until it merges`, the ignored files
  after the folder, then the `Next:` line; the fixture's path remote gets
  `open a pull request for aegonex/m2 into main on your host`, no gh, no
  guessed link), then turn 3 "the PR is merged" (Clean up at once with
  `-D`, no second question: `<sha> · merged into main · .worktrees/m2
  removed`, then the `Next:` line), V8
  exit "push what I have" (keep-ask, `.env` named), V9 a typo task with one
  reviewed part, V10 done with `AIDEV-TODO(M2)` and a failing test, V11
  exit in a task folder while `m2` waits (HANDOFF lands in the task).

### Portability

Single `git -C "<absolute folder>"` lines, never a `cd` for git; other
commands run in the unit folder (the shell's working directory, or a
`cd "<f>"` line of their own, which the install always has; v0.5.1: an
install, a test or a done-when as `cd "<f>" && <command>`, one call, since
a shell may not keep a `cd`; PowerShell 5.1 has no `&&`); Clean up
first moves the shell to `<main>` so Windows can delete the folder
(v0.5.1: in the remove's own call, `cd "<main>" && git -C "<main>"
worktree remove "<f>"`). A
file is deleted with `rm` on one quoted path per line (PowerShell
`Remove-Item -LiteralPath`), never `-r` or `-f`. `gh` is optional and
runs only for a host URL remote; git 2.23+ suffices (`switch`,
`restore`).

## v0.3 spec (2026-09-26): readable briefs

Why: users could not read the v0.2 briefs. They were label-per-line
strings full of the skills' own words (`Drift:`, `Anchors: 0 TODO · 0 NOTE`,
`tree: clean`, the HEAD sha), lines that said `none`, and a `— go?` buried
at the end of a long line that some users never saw. The answer to a Thai
user came back with English labels.

Only the replies change. What each skill reads, writes, checks and asks
permission for is the v0.2 contract, unchanged.

### Brief shape (init, plan, exit, done)

```
**<title: what happened, or what is proposed>**

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**<action label>:** <the one thing go will do>

Reply **go** to <do it>, or tell me <the alternative>.
```

- A row appears only when it has something to say. No row reads `none`,
  `0` or `-`; with no rows the table is left out.
- Not shown: the HEAD sha, NOTE and dead-end counts, raw git commands, and
  the skills' vocabulary (drift, anchor, tree).
- The brief is printed as markdown, never inside a code block, so the table
  renders. Paths, commands and commit ids go in backticks.
- Steps run without commentary: the brief is the whole reply.

| Skill | Title | Action line | Question |
|---|---|---|---|
| init | `<project> · branch <branch>` | `First step:` | `Start the first step?` — `go` / `Not now` |
| plan | `Planned: <M> <name>` + `Done when:`, then a steps table `# / Step / Done when` | the steps table | `Start step 1?` — `go` / `Change the plan` |
| exit | `Handoff saved.` / `Handoff created.` + next entry | `Will commit:` (or `Committed:` when the user already asked) | `Commit now?` — `go` / `Don't commit` |
| done, pass | `<M> <name> can close.` | `Will commit:` | `Delete and commit now?` — `go` / `Not yet` |
| done, fail | `<M> <name> cannot close yet.` + a `Check / Result` table | `First step:` | `Start the fix?` — `go` / `Not now` |
| note | none: one line `Noted (<kind>): <text>` | none | none |

### The question

- With a multiple-choice question tool: the brief is printed, then the
  question is asked with the tool, options `go` and the alternative. The
  tool adds a free-text answer by itself. Plan also asks each planning
  question through the tool, one per call.
- Without one: the reply ends with a single line containing `**go**`, alone,
  after a blank line.
- Any clear yes is go: go, ok, yes, ได้, โอเค, ลุย. Any other answer is a new
  instruction, never silence.

### Language

Every reply is in the user's language, labels included: the language of
the user's message; when only the skill's name was typed, the language of
the conversation; else the language of the state files; else English. Each
skill carries its labels in English and Thai; other languages translate
the English. The content written into `ROADMAP.md` and `HANDOFF.md` follows
the same rule; their headings stay fixed English so the other skills can
parse them, and note's kind word (`decision`, `dead end`, `fact`) stays
English in the file because exit sorts by it.

## v0.2 spec (2026-09-02) — status: implemented and verified on fixtures 2026-09-02

Why: v0.1 review found that init wrote four files into any repo on its first
message, that the anchor grep counted the AGENTS.md template itself, that
the three scaffold questions were a poor substitute for planning, and that
the init/exit contract flagged a legitimate handoff commit as drift.
The user also asked for a fourth verb: closing a unit of work and removing
the documents it no longer needs.

### Ownership

| Skill | Reads | Writes | Ends with |
|---|---|---|---|
| `aegonex-init` | AGENTS.md, ROADMAP.md, HANDOFF.md, manifests, README.md, CONTRIBUTING.md, git | after go only: `AGENTS.md`, `CLAUDE.md` when missing | one `First step:` and `go?` |
| `aegonex-plan` | ROADMAP.md, AGENTS.md, HANDOFF.md, `git log --oneline -20` | `ROADMAP.md` (structure, goal, milestones, steps, constraints, not-doing) | `First step:` of the milestone and `go?` |
| `aegonex-exit` | everything the session produced, git | `HANDOFF.md` whole file (created if missing); `ROADMAP.md` ticks, decisions and `docs:` paths only; anchor comment lines | `Commit?` and `go?` |
| `aegonex-note` | the tail of HANDOFF.md | one line under `## Session log` in `HANDOFF.md` (creates the shell if the file is missing) | `noted: <line>`, no question |
| `aegonex-done` | ROADMAP.md, AGENTS.md, git, the output of the milestone's `done when` checks | `ROADMAP.md` collapse of the closed milestone; one rule line in `AGENTS.md`; deletions only inside the proposed commit command | `Commit?` and `go?` |

Templates move with their owner: `assets/AGENTS.md` and `assets/CLAUDE.md`
stay in init; `assets/ROADMAP.md` moves to plan; `assets/HANDOFF.md` lives
only in exit.

### aegonex-init v0.2

Procedure changes against v0.1:

- Step 2 becomes a per-file table. `AGENTS.md`/`CLAUDE.md` missing: derive
  from manifests and README, list them under `missing:` in the `Repo:` line,
  create them after go. `ROADMAP.md` missing: the `ROADMAP:` line reads
  `none — aegonex-plan creates it`. `HANDOFF.md` missing: the `HANDOFF:`
  line reads `none — the first aegonex-exit creates it`; the drift checks
  that need it are skipped and the working tree is reported as is.
- The three scaffold questions are removed. `references/scaffold.md` shrinks
  to deriving `AGENTS.md` content; `AGENTS.md` rules keep a `TODO(owner):`
  marker for the user to fill by hand.
  `assets/AGENTS.md` gains a `Scratch: <dir>` line (default `docs/scratch/`),
  the only directory a skill may propose deleting from.
- Allowed reads before go: the three state files, manifests, `README.md`,
  `CONTRIBUTING.md`, the skill's own files. `git diff` on a file `git status`
  listed stays allowed.
- Anchor grep gains `--exclude={AGENTS.md,CLAUDE.md,ROADMAP.md,HANDOFF.md}`
  and drops `QUESTION`.
- Drift, commits after the handoff: list `<HEAD-in-HANDOFF>..HEAD`; the
  oldest commit in that range whose files include `HANDOFF.md` is the
  handoff commit and is removed from the list whatever else it touches;
  what remains is drift. If the sha in HANDOFF.md does not exist
  (`git cat-file -e` fails: rebase, squash, shallow clone), fall back to
  `--since="<HANDOFF date>"` with the same exclusion.
- Drift, session ended without exit: `## Session log` present in HANDOFF.md.
  The line reads `previous session ended without aegonex-exit: <n>
  session-log lines`; the lines are testimony for `First step:`.
- `First step:` is chosen in this order, first match wins: (1) the working
  tree has changes HANDOFF.md does not mention: inspect them; (2) HANDOFF.md
  names a next step: that step; (3) ROADMAP.md has an unticked step in the
  current milestone: the first one; (4) otherwise `run aegonex-plan`.
  A focus the user typed reshapes the chosen step; it never skips the
  question.
- Fresh project (no state files): the brief still prints; `Repo:` ends with
  `missing: AGENTS.md CLAUDE.md`; `First step:` reads `create AGENTS.md and
  CLAUDE.md, then run aegonex-plan — go?`. After go, init writes the two
  files and names `aegonex-plan`; it does not run it.

Brief shape (unchanged labels):

```
Repo: <project> · <branch> · HEAD <sha> · tree: clean | <n> modified: <files, max 3> [· missing: <files>]
ROADMAP: <current milestone> — <done>/<total> steps | none — aegonex-plan creates it
HANDOFF (<date>, <branch>): stopped at <…> · next: <…> · dead ends: <n> | none — the first aegonex-exit creates it
Anchors: <n> TODO · <n> NOTE — <top 3 TODOs as file:line — text>
Drift: <one line per finding with evidence> | none
First step: <one concrete action> — go?
```

### aegonex-plan (new)

Trigger: no `ROADMAP.md`; the current milestone is fully ticked; or the user
says "วางแผน", "เพิ่มฟีเจอร์", "plan", "roadmap", "new feature", "what next".

Procedure:
1. Read `ROADMAP.md` if present, `AGENTS.md`, `HANDOFF.md`, and
   `git log --oneline -20`. No source file is opened.
2. Ask one question per message, multiple choice when possible, in the
   user's language, at most seven per milestone, in this order and only
   while the answer is still unknown: who it is for and what problem it
   solves; what "done" looks like as something observable; what is
   deliberately not being done; constraints (deadline, platform, budget);
   the largest unknown or risk; the order of the steps. Stop asking the
   moment the write condition below holds.
3. Write condition: one milestone with a `done when` of its own, at most
   seven steps, every step with a `done when` that names a command, a test
   or a visible behaviour, every step small enough to finish in one
   session.
4. Write `ROADMAP.md` from `assets/ROADMAP.md`. Ticked items, existing
   decisions and existing constraints are kept verbatim; unticked items may
   be restructured; nothing is un-ticked. Headings are fixed English so init
   and exit can parse them; content is in the user's language.
5. Print the brief and stop.

`ROADMAP.md` template:

```
# ROADMAP — <project>

Goal: <one sentence>

## Milestones
- [ ] M1 — <name> · done when: <observable>
  - docs: <paths of working documents; aegonex-done proposes deleting them>
  - [ ] <step> · done when: <command, test or behaviour>
- [ ] M2 — <name> · done when: <observable>

## Not doing
- <explicitly out of scope>[ — <reason, when given>]

## Decisions
- <YYYY-MM-DD> — <decision>[ (<why>, when given)]

## Constraints
- <deadline, platform, budget, non-negotiables>
```

Brief shape:

```
Repo: <project> · <branch> · HEAD <sha>
ROADMAP written (<date>): <milestone> — <n> steps, each with done when · not doing: <n> · questions asked: <n>
Decisions: +<n> · Constraints: +<n>
First step: <step 1 of the milestone> — go?
```

Final line names `aegonex-exit` in the user's language. The skill writes no
code, no `HANDOFF.md`, and no implementation plan; an agent that has a
deeper design skill uses it on the step, not on the roadmap.

### aegonex-done (new)

`aegonex-exit` closes a session; `aegonex-done` closes a unit of work. The
unit is the milestone that `aegonex-plan` wrote. When the last milestone
closes, the project closes through the same skill.

Trigger: "เสร็จแล้ว", "ปิด milestone", "งานนี้จบ", "done", "close M2",
"ship it", "finished".

Procedure, in order; the first failing step ends the skill:

1. Prove it. Read every `done when` of the current milestone. A check that
   is a command or a test runs now and its output is kept: this is the one
   verb that may probe, because proving completion is its job. A check that
   is a visible behaviour is confirmed by the user in this session. The
   anchor grep must show no `AIDEV-TODO` that names this milestone. The
   user's word that the work is done is not evidence for a runnable check.
   Anything failing: the brief names it, `First step:` is to fix it, and
   nothing below happens.
2. Retire in `ROADMAP.md`. The closed milestone collapses to one line: name,
   `closed <date>`, last commit. Its steps and its `docs:` line are removed
   (git history keeps them). Decisions that still constrain later work are
   kept; decisions that only served the closed milestone are removed. `Not
   doing` entries that lost their meaning are removed. `AIDEV-NOTE` comments
   are never touched. `HANDOFF.md` is not touched: it belongs to exit, which
   will write `M2 closed, next: aegonex-plan`.
3. Propose the deletions. Candidates are exactly: the paths listed under the
   closed milestone's `docs:` line, and files under the `Scratch:` directory
   declared in `AGENTS.md`. Nothing else is ever a candidate; without a
   `docs:` line and without `Scratch:`, the `Cleanup:` line reads `none
   declared`. On project close, `HANDOFF.md` is also a candidate: there is
   no session to hand off to. The skill deletes nothing itself. Every
   deletion is part of the proposed commit command (`git rm` for tracked
   files, `rm` for untracked ones, which git cannot restore), so the user
   sees the complete list before one `go`.
4. Retrospective. From the milestone's dead ends (ROADMAP, HANDOFF, the
   session), pick the one that would have saved the most time had it been a
   rule, write it as one line under Rules in `AGENTS.md`, and show it in the
   `Retro:` line. `none` when no dead end generalises. This is the only
   write any skill makes to `AGENTS.md` after scaffolding; it goes into the
   same commit, and the user strikes it with the go if they disagree.
5. Print the brief and stop.

Brief shape:

```
Repo: <project> · <branch> · HEAD <sha>
Checks: <passed>/<total> done when passed · <failed checks> | milestone not done: <what is missing>
ROADMAP: <milestone> closed (<date>) · <n> steps collapsed · decisions kept <n>, dropped <n>
Anchors: <n> TODO for this milestone (must be 0) · <n> NOTE kept
Cleanup: <paths, tracked | untracked> | none declared
Retro: <rule added to AGENTS.md> | none
Commit? `git rm <tracked> && rm <untracked> && git add ROADMAP.md AGENTS.md && git commit -m "chore: close <milestone>"` — go?
```

Final line: `next: aegonex-plan` while milestones remain, `project closed;
end with aegonex-exit` when none do. A skill cannot clear the harness
context; the line after the closer hands the user `/clear` (the finished
milestone's context is dead weight, and init rebuilds the picture from the
files).

Never-close-on-word rationalizations, from the same family as exit's:
"The user said it is done, ticking is a formality" → the user's word covers
behaviours they saw, not commands that can run; "The failing check is
flaky, the code is fine" → a flaky check is a failing check, write it under
what is missing; "I'll delete the scratch files now, they are junk anyway"
→ nothing is deleted outside the approved commit command.

### aegonex-note (new)

Why: every other write happens at exit. A session cut by quota, a crash or
an automatic compaction never reaches exit, and what it decided and tried
is gone. `aegonex-note` writes the three facts git cannot reconstruct the
moment they happen.

Trigger, two ways, both first-class:
- By the agent, from the description, when one of three things happens in
  the session: the user makes a decision (what and why); an approach that
  was tried is abandoned (dead end); an environment fact is learned (a
  command needs a flag or a variable, a tool is missing). Not for progress
  ("started X"), not for anything a commit or a diff already shows.
- By the user: "จดไว้", "จำไว้ว่า", "ทางนี้ไม่ได้ผล", "note this",
  "remember that".

Procedure:
1. Compose one line: `- <HH:MM> <decision|dead end|fact>: <text>`, at most
   120 characters, paths allowed, no code. The secret grep of exit runs on
   the line before it is written; a hit becomes `<redacted>`.
2. Append it under `## Session log` at the end of `HANDOFF.md`. If the
   section is missing, add it. If `HANDOFF.md` is missing, create a shell:
   the `# HANDOFF — <date>` header, the `Branch:`/`HEAD:` line and the
   section. Exit still owns the file and overwrites it.
3. No question is asked. A note that waits for `go` is as fragile as exit
   is; the write is one line and git keeps it. The reply is that line,
   prefixed `noted:`, and nothing else; the session continues.
4. When the section reaches twelve lines the reply adds one more line:
   `session log is long: run aegonex-exit`.

Reads the tail of `HANDOFF.md` only. Writes one line. Never edits another
section, `ROADMAP.md`, `AGENTS.md` or code. The append is the only write
any skill other than exit makes to `HANDOFF.md`.

What the other skills do with the log:
- `aegonex-exit` starts step 2 (session facts) from the log, folds each
  line into Decisions, Dead ends or Notes for the next session, and the
  rewrite from the template drops the section.
- `aegonex-init`: exit always removes the section, so any `## Session log`
  present at init means the previous session (or this session, before a
  compaction) ended without exit. The `Drift:` line reads `previous session
  ended without aegonex-exit: <n> session-log lines`, and those lines count
  as testimony when choosing `First step:`.

A harness-side complement, Claude Code only and not required: a
`PreCompact` hook that injects "run aegonex-note for anything not yet
noted" before the context is compacted.

### aegonex-exit v0.2

- `HANDOFF.md` missing: create it from `assets/HANDOFF.md`; this is the
  normal path for a project's first exit, not an exception.
- `ROADMAP.md` missing: skip step 3 and print
  `ROADMAP: none — aegonex-plan creates it`.
- Reconcile understands the v0.2 template: a step is ticked only when its
  `done when` was observed in the session (command output, test result, the
  user's word). `(in progress)` is present at most once per line.
- Never-probe rule gains a rationalization row: "I need a passing test to
  tick this" → "A run now is a new task. Tick only what ran during the
  session; otherwise leave `[ ]` and write `not re-run` in Stopped at."
  and a red flag: "Let me run the tests so I can tick it."
- Secret scan after saving is one fixed command:
  `grep -nEi 'KEY|TOKEN|SECRET|PASSWORD|Bearer|sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' HANDOFF.md ROADMAP.md AGENTS.md`.
- Anchor grep: same exclusion as init, no `QUESTION`.
- Step 2 starts from `## Session log` in HANDOFF.md when it exists; each
  line is folded into Decisions, Dead ends or Notes, and the rewrite drops
  the section.
- New documents the session created (files `git status` shows as new under
  `docs/` or the `Scratch:` directory) are added to the current milestone's
  `docs:` line, so `aegonex-done` can find them later.

### Flaws closed by this spec

From the 2026-09-02 review: 1 (scaffold without go), 2 (anchor self-hit),
3 (README not in the allowed list), 4 (partial scaffold and CLAUDE.md), 5
(missing sha fallback), 6 (HANDOFF "nothing in flight" while dirty: init no
longer writes it), 7 (QUESTION), 9 (probe leak), 10 (in-progress repeated),
11 (handoff commit flagged as drift), 12 (secret grep undefined), 13
(ROADMAP line when no file). Still open: 8 (unplanned compaction gives a
picture only as fresh as the last exit; documented, not solved) and 14
(size; trimmed opportunistically while editing).

### Testing

Same method as `docs/testing.md`: RED without the skill, GREEN with it,
Sonnet subagents on copied fixtures, a judge checks the disk.

| Fixture | Scenario | Pass when |
|---|---|---|
| fresh-app | init, "start work" | brief printed, zero files written before go; after go exactly `AGENTS.md` and `CLAUDE.md` exist; `First step` names `aegonex-plan` |
| stale-app | init, "start work" | three drift lines with evidence; no source file opened; the fixture gains one handoff commit that touches `HANDOFF.md` and `src/`; it is not listed as drift |
| planned-app (new: current milestone fully ticked) | init | `First step` reads `run aegonex-plan` |
| fresh-app after go | plan, "วางแผน" | at most seven questions, one per message; `ROADMAP.md` matches the template; every step has `done when`; `Not doing` non-empty; no code written |
| stale-app | plan, "plan the next milestone" | ticked items and decisions unchanged byte for byte; unticked M3 restructured |
| session-end-app | exit, "done for today" | no test or install command run; `(in progress)` once; HANDOFF ≤ 60 lines; no commit; secret grep clean |
| noinit-app | exit, "wrap up" | `HANDOFF.md` created; `ROADMAP:` line says none; final line points to `aegonex-init` |
| closed-app (new: every `done when` passes, two docs listed, one untracked scratch file) | done, "เสร็จแล้ว" | checks run with output shown; milestone collapsed to one line; nothing deleted before go; the proposed command lists exactly the two docs and the scratch file; no commit |
| closed-app with one failing check | done, "done" | no ROADMAP change, no deletion, `First step` names the failing check; the user insisting does not change the outcome |
| stale-app, mid-session | note, "ตัดสินใจแล้วว่า refresh window 60s" | exactly one line appended under `## Session log`; nothing else in the file changed; the reply is the `noted:` line; no question |
| stale-app, mid-session, no user phrase | agent tries an approach that fails, then switches | RED: nothing written; GREEN: a `dead end` line exists before the agent continues |
| stale-app, mid-session | note, text containing a token | the line holds `<redacted>`, no fragment of the token anywhere |
| stale-app with a `## Session log` (new variant) | init, "start work" | `Drift:` names the session that ended without exit and the line count; `First step:` uses the log |

### Versioning

All five skills ship as `0.2.0`. `README.md` gains the `aegonex-plan`,
`aegonex-note` and `aegonex-done` rows and install lines. `skills/aegonex-init/assets/HANDOFF.md` and
`assets/ROADMAP.md` are deleted from init (moved to exit and plan).

## Review by a fresh subagent whenever the tool exists (2026-09-27)

The defect (the first item v0.5.1 left for later): the leader reviewed
its own work while the harness offered a subagent tool. V10's go on a
cannot-close brief fixed a one-line check, reviewed the fix itself and
marked the line `(review not independent)`. M1's go, in a parent folder,
ran backend's milestone step and reviewed it itself in both v0.5.1 runs.
R2 (v0.4) says a separate reviewer checks every part, even a one-part
typo fix, and only a harness without subagents gets the marker.

The wording let a model take the other branch:
- Leader mode 2, `(with subagents; none: part by part in <f>: edit,
  **Review**, commit on PASS before the next)`. `none` has no noun, so it
  read as "no part folders", which is the path for one part in `<f>`, and
  there **Review** sits between two things the leader does. M1's trace
  says so: "the step was one file in one folder, so Leader mode ran it
  directly".
- Leader mode 4, `a fresh read-only subagent, not its writer (none: you)`.
  `none` can again mean "no separate writer", which is the case whenever
  the leader wrote the part.
- Done step 7, `without subagents, review it yourself before that
  commit` and `the parenthesis only without subagents`. "Without
  subagents" reads as a choice, not a missing tool, and all three reply
  templates carried the marker, so the line to copy was the self-review
  one.

Candidates:
1. Name the condition as the tool, in each place the self-review branch
   appears, and take the marker out of the lines to copy.
2. One sentence at the head of Leader mode, "you review only with no
   subagent tool": the sections are 43 lines and every line is full.
3. A writer subagent for a part in `<f>` too (Dispatch): the rule is
   about who reviews, whoever wrote the part, and the Dispatch sentence
   is other work.
4. Leave the text and rely on the scenario prompts: M1's and V10's
   prompts name no subagent tool, and neither does a real session.

Decision: 1, in two rounds, under the same `(aegonex 0.4)` headings.

Round 1 changed the three places:
- Leader mode 2: `**Part folders** for 2+ parts with a subagent tool
  (else one by one in <f>: edit, **Review**, commit on PASS)`. The path in
  `<f>` became the else of that condition, for one part or for no tool.
  `before the next` went for room, since `one by one` says it.
- Leader mode 4: `**Review** every part, a one-line fix in <f> too: a
  fresh read-only subagent (no subagent tool: you) runs the done-when,`.
  The only branch to the leader is a missing tool. `not its writer` went:
  `fresh` already excludes the writer, and the tool condition excludes a
  leader that wrote the part. Its last line, `by you: end (review not
  independent)`, is unchanged.
- Done step 7: "A fresh read-only subagent reviews it, a one-line fix
  too, whenever you have a subagent tool; with no subagent tool, you
  review it yourself before that commit." The lines under the title
  became `Fixed: <files> committed` / `แก้แล้ว: commit <files>` and
  `FAIL: <evidence>`, followed by "a review of your own ends it with
  `(review not independent)`, never translated".

V10 passed on round 1 and M1 did not. M1's leader again reviewed the step
itself, citing Leader mode's "one part in `<f>`" path "(edit, review,
commit directly)". It never quoted item 4. Item 2's else still listed
**Review** between two things the leader does and named no reviewer, and
subagents appear only with "2+ parts" and Dispatch's writers. A model
that takes item 2's one-part path as complete never reaches item 4.

Round 2 names the reviewer where the one-part path is read. Leader mode 2
is now `**Part folders** for 2+ parts with subagents (else one by one in
<f>: edit, subagent **Review**, commit on PASS)`. `with a subagent tool`
went back to `with subagents` for the room. With no subagent tool,
`subagent **Review**` still leads to the leader through item 4's
parenthesis: item 2 names the usual reviewer, and the exception stays in
one place. Leader mode 4 and done step 7 keep round 1's text.

On the final text, V10 and M1 ran twice each (`docs/testing.md`). All
four leaders started a fresh reviewer after the edit and before any
commit, none reviewed its own part, and no reply carried the marker.
Those that failed did so on what the review read or what followed a
FAIL.

Counts: SKILL.md 1,415 lines, unchanged (done 378, and step 7 keeps its
9 lines). The AGENTS.md sections stay at 43 lines, the longest 125. The
`version:` lines are left for the land.

Known limits:
- Projects set up before this change keep their copy of the sections:
  setup appends only a missing section, and the headings stay. Their
  Leader mode still says `(none: you)`. Done step 7 carries the rule for
  its own fix; other work there reads the old text.
- Whether a subagent tool exists is the agent's own judgement. A harness
  that offers one only after a tool search may still read as having none.
- An independent reviewer knows less than the leader. In V10 rounds 2
  and 3 the reviewer failed a correct fix on `docs/scratch/try.md`, a
  Scratch file that was there before it: item 4's "new files" and step
  7's "every new file" do not say new since when. After that FAIL, round
  2's leader started a second reviewer with a prompt that argued against
  the first and committed on its PASS; round 3's replied `FAIL:` as step
  7 says, but step 7 then reruns the checks on the uncommitted fix, and
  the next go would commit it as `wip` unreviewed. Leader mode 4 and 5
  do not say a FAIL stands.
- Leader mode 4 lists what the reviewer reads but gives no prompt to hand
  over. M1's leaders narrowed the diff to one file, and round 3's left
  out status and new files. No prompt carried the whole command rule:
  reviewers ran `; echo` of the exit code and `;`-chained git or reads.
  A general-purpose reviewer has write tools and is read-only only by
  its prompt.
- Each of these sits in the Review prompt, item 5 or step 7's FAIL path,
  which are other work; this change leaves them as they were.

## A parent session's notes and land go, and init's Opened line (2026-09-27)

The defects, from the scenario rounds of the command rule (`docs/testing.md`,
its "Left for later"); none comes from that rule:
1. init's go reply had no `**Opened:**` line when the first step's folder
   already existed (M1, 2 of 3 runs). Step 4 opens only a missing folder,
   and the agents read step 5's line as "opened by this go".
2. `repos.md` section 7's land go ran the landed check once, before Sync,
   while section 3 asks callers to rerun it after Sync (M3).
3. `scaffold.md`'s "`AGENTS.md` missing" path did not name the Repos
   section, which `repos.md` section 11 names: M1 round 2 wrote admin's new
   AGENTS.md without it.
4. Note in a parent session (M3): lines in English under a Thai reply, the
   secret grep skipped, no `Noted (<kind>) in <r>: ...` line opening the
   reply, and once the note written after the parts merged. Section 8 read
   "Note's step 3 in each repo", which the agents took for the whole
   procedure, and section 7's "Then note writes" set no place against
   dispatch.
5. The land order, the agent's call, never became an `(agent's call)`
   decision (M3). The v0.5 spec says "a Decision marked `(agent's call)`
   (a task: its Note)", but section 7 never asked note for it.
6. The land go's reply wrote `.worktrees/<u>` without `<r>/`: section 7
   pointed at the single-repo form, against section 1's "paths read
   `<r>/.worktrees/<u>`".

Decisions:
- The Opened line always opens init's go reply and names the step's
  folder, whether the go opened it or it existed (init step 5, `repos.md`
  section 5). A second label for an existing folder (`Working in:`) was
  turned down: one more form, and the `init-go` judge and every earlier
  round expect `**Opened:**`.
- The land go runs the landed check again only when Sync merged anything,
  the grader's fix, and section 3 now says the same, so done and the
  parent go read one rule. A record comes in only through a merge, and
  Sync's own `merge-base --is-ancestor` exit code says whether it merged.
  An unconditional rerun is simpler to state, but it is a read for
  nothing whenever Sync merged nothing, as in every M3 round so far,
  where no agent reran it.
- `scaffold.md`: after either `AGENTS.md` path, a repo under a parent
  folder gets `assets/AGENTS-repos.md` when its heading is missing, a new
  file too.
- `repos.md` section 8 runs "Note's steps 1-6 in each repo concerned", and
  the reply starts with the Noted lines. note's Language covers a line the
  agent words itself (a done-when, a land order) and keeps `done when:`,
  `after:` and `(agent's call)` English with the kind words, since other
  skills search for them: a translated `done when:` would hide the check
  from done step 3. Step 2's grep runs on every file written, never
  skipped; step 5 puts the noted lines first, a line each, above a
  leader's report; the red flags say both.
- Section 7: before dispatch, note writes, in the user's language, each
  repo's done-when, each consumer's record and, unless the user named
  the order, a decision in each repo that backend lands first, ending
  `(agent's call)`. Turned down: the marker
  on the land question alone (seen when the user decides, kept nowhere,
  and wrong when the user named the order), and the decision in the
  consumer alone (the provider's next session would not know why it lands
  first). A line in each repo is plan's rule for milestones, an
  `(agent's call)` Decisions line in each touched ROADMAP.md, carried to a
  task; exit folds it into Decisions. The same sentence ends "its reply
  lines open the report": in the first M3 rerun the leader read note's
  step 5 and section 8, wrote the notes before dispatch, and still opened
  its report with the review lines, since the report's form is in section
  7 and the Leader mode of AGENTS.md, not in note. Section 7 is where the
  leader composes the report, so the rule is said there too. The
  decision is described, not quoted: the first two M3 reruns copied the
  quoted `backend lands first (agent's call)` word for word into a Thai
  session's notes. The third, with the description, still wrote the
  lines in English first and rewrote them in Thai only after the parts
  merged, so the sentence names the language too: note's Language says
  it, but the leader composes from section 7's English prose.
- Section 7's reply: "a line per repo in the land go's form, paths
  `<r>/.worktrees/<u>`". Its "led by the repo" went, for the line budget:
  section 1 already says reply lines lead with `<r>: `.

Line counts do not change: SKILL.md 1,415 (init 323 and note 137 edited
in place; plan, exit and done untouched), `repos.md` 99, `scaffold.md` 89;
`assets/` is untouched, so the AGENTS.md sections stay 43 lines under the
same `(aegonex 0.4)` headings. To fit `repos.md`, section 3 names the
sibling as `<main>/../<r>` (the Repos section's own form), one line
fewer, and section 7 takes one line more after small cuts ("its
**Open**", "its records", "stops the rest", "(init's go or the leader's
start)", "lands only the repos", whose land question then names only
them). The versions stay `0.5.1`:
the number is chosen when this lands.

## Subagent prompts carry the command rule (2026-09-27)

The defect (v0.5.1 known limits): a subagent that does not load the
project's AGENTS.md, and none did in the scenario harness, keeps
**Commands** only as far as the leader writes it, and Leader mode 3
(Dispatch) and 4 (Review) asked for no command rule at all. In M3's last
v0.5.1 round three of six subagent `node --test` runs ended in `; echo
"EXIT_CODE=$?"`, which the leader's own prompts invited ("exits with
status 0", "note the exit code"); a reviewer ran a bare `cd` before its
chain; writers put several commands in one call and committed with
heredoc messages; V9's writer and V12's reviewer each ran a multi-line
call.

Four smaller Leader mode defects came with it:
- Dispatch's quoted sentence says "commit there" to every writer, while a
  part in `<f>` is reviewed uncommitted (`status --short`, `diff HEAD`)
  and committed by the leader on PASS (V9, V12: the leaders chose right).
- Mode 2's "commit `<f>` first, naming each file" and mode 5's "`<f>`
  work: commit it naming its files" read as covering a note's HANDOFF.md,
  which aegonex-note leaves uncommitted for exit; M3's second v0.5.1
  round committed it and lost the exit-first line.
- "Reply per part" does not say whose reply: the leader's is meant to
  carry the reviewer's line (M1 left it in the trace).
- A leader ticked a ROADMAP step itself (M1), though ticks are exit's.

The two sections have 43 lines and no spare one, and a line elsewhere
would have to come from Go or Unit, which hold v0.4's tested strings.
Five texts were tried, each on V9, V12 and M3's first turn
(`docs/testing.md`, "Subagent prompts carry the command rule"):
1. **Commands** verbatim as an item of Dispatch's list: no leader of
   three copied it. V12's and M3's wrote their own line ("each its own
   shell call, absolute path, no chaining"); V9's writer got none and
   chained two `grep`s with `;` and `echo`.
2. A pointer inside Dispatch's quote, "follow **Commands** in
   <folder>/AGENTS.md": every leader rewrote it as "Follow the Commands
   section", the project's `## Commands`, "for how to run tests". Three
   of four writers opened the file and two of them still broke the rule;
   no reviewer prompt carried it. 12 of 27 subagent calls broke the rule.
3. The rule's text inside Dispatch's quote, with **Commands** reduced to
   "as in Leader mode 3's quote": every writer prompt carried the rule,
   but two of three leaders wrote the reviewer's prompt from mode 4,
   which named no rule, and V9's reviewer echoed `$?` four times.
4. As 3, plus "as is" before the quote and "told 3's quote" in Review:
   every writer prompt, and V9's and V12's reviewer prompts, carried the
   whole rule (M3's reviewers four of its seven phrases); 2 of 22
   subagent calls broke it, both heredoc commits. But V9's leader, whose
   **Commands** now only pointed into Leader mode, ran its land go with
   seven `git` calls without `-C`, a `; echo "exit:$?"` and a relative
   remove path.
5. The rule back in **Commands**, as a quoted sentence the leader follows
   itself, and in Dispatch's quote a slot for it, `<**Commands** quote>`,
   which the leader fills as it fills `<folder>`.

Decision: 5. A leader copies Dispatch's quote into every prompt, lightly
reworded at most (every writer prompt of rounds 1 to 4 kept "never
merge, push, delete or ask the user"), so the rule must be inside the
quote; a slot is filled like `<folder>`, where a pointer (2) is passed on
as a pointer; and the leader keeps its own rule in its own bullet (4).
In round 5 six of seven prompts carried every clause and the leaders'
own commands had one fault in 98 calls (a multi-line commit).

Round 5 also showed three gaps, closed in the final text without another
agent round (the coordinating session ended the runs there):
- A pipe: V9's writer ran `cat -A "<abs>/README.md" | head -20`, which
  the rule did not name. It now forbids `|`.
- A commit message over several lines: V9's leader committed with a
  three-line `-m` (a `Co-Authored-By:` trailer), as round 4's writers did
  with heredocs. The rule now says "commit: one `-m` line".
- Review's read of `<f>`: a parallel review of Leader mode found that
  "new files" made reviewers fail a correct fix over a file that already
  existed. Review now reads `status --short`, the full `diff HEAD` (no
  path) and the `??` files of that status.

**Commands** now reads: "one command per call and line, absolute paths,
no `&&` `||` `|` `;` `$?` or lone `cd`, but tests, install, remove:
`cd "<folder>" && <command>`; git: `git -C "<folder>"`; commit: one `-m`
line", reads too; no error: exit code 0. It forbids any `$?`, not only
`; echo $?`, and a lone `cd`, the two faults M3's subagents showed.

Leader mode:
- Dispatch: "each prompt, a reviewer's too, stands alone: folder (`<p>`
  writer: commit there), files, done-when, as is: "Work only in <folder>;
  <**Commands** quote>; never merge, push, delete or ask the user."" Only
  a writer in a part folder `<p>` commits; a part in `<f>` is committed
  by the leader on PASS.
- Review: `<f>`'s read as above, the reviewer "told 3's quote", since
  leaders write its prompt from mode 4; "Your reply quotes: `PASS: ...`",
  so the leader's reply carries the reviewer's line as written (V12's
  leaders put it in Thai words in every round).
- Mode 1 reports "(no tick)"; mode 2 commits `<f>` "naming non-state
  files"; mode 5: "`<f>` part: commit its files by name".

The room came from text a rule already says:
- Dispatch drops "install command" and `git as git -C "<folder>"`: the
  quote carries both.
- **Commands** drops `|| true` (its `||` forbids it), "always", the
  `; echo` of `; echo $?`, and "tool result" (the skills keep "from the
  tool result (no error shown: 0)"); install and remove join tests inside
  the quote instead of "as tests" after it.
- Review's `<f>` read leaves its two `git -C "<f>"` to the quote, and
  "Your reply has its line:" became "Your reply quotes:".
- Mode 1: "What skills write (...): no review." (was "What aegonex skills
  write (...) gets no review."); mode 2 drops "first" (the order of its
  clauses says it).

Untouched: mode 2's `(with subagents; none: ...)` and mode 4's `(none:
you)` (their lines are byte for byte v0.5.1's), done step 7, the
`(aegonex 0.4)` headings and the `version:` lines.

Changes (line counts unchanged: SKILL.md 1,415, with init 323, plan 225,
note 137, exit 352, done 378; `repos.md` 99; the AGENTS.md sections 43
lines, longest 125): `assets/AGENTS.md` only, **Commands** (lines 40-41)
and Leader mode lines 65, 67, 69-70, 72-73 and 75-76. This closes three
items of v0.5.1's "Left for later": the prompts without the rule and
Dispatch's "commit there" for a part in `<f>`; Leader mode 2 and 5
committing a note's HANDOFF.md; whose reply repeats the reviewer's line.

Known limits:
- A leader may still fill the slot in its own words and drop clauses:
  V12's round 5 reviewer prompt had three of the seven. The checks read
  only the leader's trace; the prompts show only in the transcripts.
- A subagent may break a rule its prompt holds: in round 5 M3's backend
  writer reran its test with `; echo "EXIT_CODE=$?"` though its prompt
  said the exit code comes from the tool result.
- A reviewer of a part in `<f>` sees the note's untracked HANDOFF.md, now
  one of the `??` files it reads, and may fail the part for it (V12, two
  runs); the leaders then reran the review with HANDOFF.md named out of
  scope.
- The final text's pipe, one `-m` line, Review read and "quotes" ran in
  the labs only, not in an agent scenario.
- Projects set up before keep their copy of the sections, as in v0.5.1.
