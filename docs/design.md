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
   command on its own call (lifecycle 3).
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
   the install command, each its own call, once); step 10 is `rm
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
   its own call (an install line of `none` is skipped). A failed install
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
   <remote>/<Base>`, **Update**, `worktree remove`, `branch -d`. The reply
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
| total | 1,077 | 1,399 | limit 1,400; largest file 373, limit 380; the AGENTS.md sections 42 lines, none over 125 characters (v0.4.1: exit 349, total 1,400, sections 43 lines) |

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
`cd "<f>"` line of their own, which the install always has); Clean up
first moves the shell to `<main>` so Windows can delete the folder. A
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
