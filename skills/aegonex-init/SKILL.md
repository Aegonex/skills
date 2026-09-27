---
name: aegonex-init
description: Use when a work session starts on a project — the first message of the day, "เริ่มงาน", "start work", "where were we", "ต่อจากที่ค้างไว้", "continue from yesterday", "boot" — or when opening a project that has no AGENTS.md, ROADMAP.md or HANDOFF.md yet. Also use when a session resumes after context was compacted or the user mentions a handoff.
license: MIT
metadata:
  author: Aegonex
  version: "0.4.0"
---

# aegonex-init

## Overview

Every session opens through this skill. It rebuilds the working picture from
the state files and git, then hands the user one decision and writes nothing
until the answer. After go it sets the project up when needed, moves stray
changes out of the main folder and opens the first step's unit folder: all
work lives in `.worktrees/<u>` on branch `aegonex/<u>` (`Working mode` in `AGENTS.md`).

Core principle: **git is the truth, the files are testimony.** Whenever they
disagree, the disagreement is reported, never silently resolved.

The state files, each with its own owner and rate of change:

| File | Answers | Written by |
|---|---|---|
| `AGENTS.md` | stack, commands, rules, session ritual, working and leader modes | init creates it or adds the two sections once; the user edits it |
| `ROADMAP.md` | goal, milestones, steps with `done when` | `aegonex-plan` |
| `HANDOFF.md` | where the last session stopped, the next step, dead ends | `aegonex-exit` |
| `CLAUDE.md` | `@AGENTS.md`, so Claude Code reads `AGENTS.md` | init creates it or adds the line once |

Spot-level state lives in the code as anchor comments: `AIDEV-TODO:` (pending
work at that spot) and `AIDEV-NOTE:` (an invariant that must survive edits).
Sibling verbs: `aegonex-plan` writes the roadmap, `aegonex-note` records a
decision or dead end as it happens, `aegonex-exit` closes a session, `aegonex-done` closes a milestone.

## When to use

- The user opens a session: "เริ่มงาน", "start", "where were we", "ต่อจากเมื่อวาน".
- A project has none, or only some, of the state files.
- Context was just compacted and the working picture is gone.

Not for: ending a session (`aegonex-exit`), planning (`aegonex-plan`), or mid-session code questions.

## Language

Every reply is in the user's language: labels, content, the question and its
options (`go` stays `go`). That is the language of the user's message; a
message with no language of its own (only the skill's name, or a bare `go`,
`ok`, `yes`) takes that of the conversation so far, else of `HANDOFF.md` and
`ROADMAP.md`, else English. Labels are given in English and Thai (another
language: translate the English); paths, commit subjects and quoted notes stay as they are.

## Procedure

Run the steps in order and without commentary: the brief is the whole reply.
Before go the procedure reads only: the four state files, manifests
(`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` and the like),
`README.md`, `CONTRIBUTING.md`, and this skill's own files. A `diff` of a
file that a `status` listed is git output and is allowed; opening `src/…`
or any other code file is not. Every command, `pwd` and `ls` included, is its
own tool call on one line, with no `&&`, `||` or `;`; an exit code comes from
the tool result (no error shown is 0), never `; echo $?` or `|| true`. Git is
always `git -C "<absolute folder>" ...`, even where the shell already stands;
never `cd` to run a read. Status always takes `-c core.quotePath=false` (as
below), so its paths can be given back to git.

### 1. Git facts

```bash
git -C "<here>" worktree list --porcelain  # <here>: absolute path of the folder you are in. First worktree path: <main>. The rest: unit folders
git -C "<main>" branch --show-current
git -C "<main>" -c core.quotePath=false status --short   # changes in the main folder
git -C "<main>" branch --list "aegonex/*"
```

Run each line as written, even where the shell already stands; never `cd`.
A `branch refs/heads/aegonex/<u>` line (not `--p<k>`) marks an open unit `<u>`
and its folder `<f>`; for each: its status, `git -C "<f>" log --oneline -5` and
`git -C "<f>" log -1 --first-parent --no-merges --format=%s`:
`chore: close <u>` means **closed**. A listed `aegonex/*` branch with no
folder is a **leftover**. The folder you are in is a **harness folder** when
it is a linked worktree outside `<main>/.worktrees/`. The **state folder** is
the open `m<n>` folder that is not closed; else the only open `t-` folder
that is not closed; else `<main>`. `<Base>` and `<remote>` are the `Base:`
and `Remote:` values in `<main>`'s `AGENTS.md` (before setup, the values
`references/scaffold.md` derives). Run `date +%F` (PowerShell:
`Get-Date -Format yyyy-MM-dd`), `git -C "<state folder>" rev-parse --short HEAD`
and `git -C "<state folder>" log --oneline -5` for the checks below.

### 2. The state files

Read `AGENTS.md` and `CLAUDE.md` in `<main>`; `ROADMAP.md` in the open `m<n>`
folder, closed or not, else the state folder; `HANDOFF.md` in the state folder.

| File | Missing | Present |
|---|---|---|
| `AGENTS.md` | setup: derive its content now (`references/scaffold.md`), name it in `Missing files`, write it after go | read it; no `## Working mode (aegonex 0.4)` heading means setup, with the sections named in `Missing files` |
| `CLAUDE.md` | setup, as `AGENTS.md` | no `@AGENTS.md` line means setup |
| `ROADMAP.md` | name it in the `Missing files` row: `aegonex-plan` creates it | read it: the current milestone is the open `m<n>` that is not closed, else the first `- [ ] M…` line without `· closed`; count its `- [ ]`/`- [x]` steps (the `docs:` line is not a step) |
| `HANDOFF.md` | name it in the `Missing files` row: `aegonex-exit` creates it when the session ends; drift checks that need it are skipped | read it |

Init never creates `ROADMAP.md` or `HANDOFF.md` or asks planning questions;
on the go it writes only what the `Setup`, `Will move` and `Work folder` rows and the first step's `update the main folder` name.

### 3. Anchors

```bash
git -C "<state folder>" grep -n --untracked -E "AIDEV-(TODO|NOTE)" -- . ":(exclude,glob)**/AGENTS.md" ":(exclude,glob)**/CLAUDE.md" ":(exclude,glob)**/ROADMAP.md" ":(exclude,glob)**/HANDOFF.md"
```

Keep the TODOs as `file:line — text`; NOTEs do not appear in the brief.
The grep line is the whole anchor. The file is not opened for context, not
with `cat`, `head`, `sed` or a file-read tool; context arrives after go.

### 4. Drift checks (required)

Each true check becomes a row of the brief naming its evidence: the two
branch names, the commits, the files, the line count. "HANDOFF looks out of
date" without evidence is not a finding; a false check leaves no trace.

| Check | How |
|---|---|
| Branch mismatch | `Branch:` in HANDOFF.md ≠ the state folder's branch, and that branch still exists (`git -C "<state folder>" rev-parse --verify -q refs/heads/<branch>`) |
| Commits after the handoff | `H` = the sha after `HEAD:` in HANDOFF.md. If `git -C "<state folder>" cat-file -e H` succeeds, `git -C "<state folder>" log --no-merges --oneline --name-only H..HEAD`; if it fails (rebase, squash, shallow clone) or there is no `HEAD:` line, `git -C "<state folder>" log --no-merges --oneline --name-only --since="<HANDOFF date> 00:00"` (a bare date means today's time of day). From that list drop the oldest commit whose files include `HANDOFF.md`: that is the handoff commit, whatever else it touches. Also drop commits whose only files are `HANDOFF.md` and/or `ROADMAP.md`, and `chore: close` commits. Whatever remains is drift; quote it, nothing older. |
| Unrecorded work | a unit folder's status lists files, other than `HANDOFF.md` and `ROADMAP.md`, that HANDOFF.md does not mention. Characterise each with `git -C "<f>" diff --stat` or `git -C "<f>" diff -- <file>` (`<f>` the folder whose status lists it) in a few words (what changed), not by opening the file. |
| Session ended without exit | HANDOFF.md contains `## Session log`. Exit always removes that section, so its presence means the last session (or this one, before a compaction) never reached exit. Count its `- ` lines; they are testimony for the first step. |
| Oversized handoff | HANDOFF.md is longer than 60 lines |
| Main folder not clean | `<main>`'s status lists files (apart from what setup commits), or `<main>` is not on `<Base>` |
| Main folder behind | `git -C "<main>" log --oneline -1 <Base>..<remote>/<Base>` prints a line (no remote: skip) |

### 5. The brief

The reader may not know git or this skill's words. The brief is a bold title,
one table, the bold first step and the question, in plain markdown (no code block):

```
**<project> · branch <branch>**

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**First step:** <one concrete action>
```

Rows come in this order, each only when it has something to say: no row reads
"none", "0" or "-" or repeats a fact; with no rows, the table is left out.

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| Current work / งานปัจจุบัน | `<M> <name>: <done> of <total> steps done` / `<M> <name>: เสร็จ <done> จาก <total> ขั้น` | `ROADMAP.md` has a current milestone |
| Work folder / โฟลเดอร์งาน | `.worktrees/<u>` of the first step, `new` / `ใหม่` when go opens it, `this folder` / `โฟลเดอร์นี้` when go adopts a harness folder | the first step works in a unit |
| Other work / งานอื่นที่เปิดอยู่ | each other open unit: `<u>`, `<u>: waits for its pull request` / `<u>: รอ merge pull request` (closed and `<remote>/aegonex/<u>` exists), `<u>: closed, run aegonex-done` / `<u>: ปิดแล้ว เรียก aegonex-done`; each leftover: `<u>--p<k>: part left over` / `ส่วนงานค้าง`, `aegonex/<u>: no folder` / `ไม่มีโฟลเดอร์` | there are any |
| Last stopped at / ครั้งก่อนหยุดที่ | HANDOFF's Stopped at in a few words, its date in brackets | `HANDOFF.md` has a Stopped at |
| Unfinished session / session ก่อนไม่ได้ปิด | `<n> notes left; aegonex-exit never ran` / `มีบันทึกค้าง <n> บรรทัด ไม่ได้ปิดด้วย aegonex-exit` | `## Session log` is present |
| Branch mismatch / branch ไม่ตรง | `on <current>, handoff written on <branch>` / `ตอนนี้อยู่ <current> แต่ handoff เขียนไว้บน <branch>` | the branches differ |
| New commits / commit ใหม่ | `<sha> <subject>` for each commit after the handoff, at most 3, then `+<n> more` | drift commits remain |
| Uncommitted work / แก้ค้างอยู่ | `<file>: <what changed>` for the files of the `Unrecorded work` check, at most 3 | there are such files |
| TODO in code / TODO ในโค้ด | `<file:line> <text>`, at most 3 | a TODO sits in a file no other row names |
| Handoff too long / handoff ยาวเกิน | `<n> lines, limit 60` | `HANDOFF.md` is over 60 lines |
| Missing files / ไฟล์ที่ยังไม่มี | each missing state file and what makes it: `AGENTS.md`, `CLAUDE.md` or `the Working mode and Leader mode sections` / `ส่วน Working mode และ Leader mode` after go; `ROADMAP.md` by aegonex-plan; `HANDOFF.md` by aegonex-exit when the session ends | a state file or section is missing |
| Setup / ตั้งค่า | `Base <Base> · Remote <remote or none>` / `Base <Base> · Remote <remote หรือ none>`, then each of `AGENTS.md`, `CLAUDE.md`, `.worktrees/.gitignore` and an existing `.dockerignore` that the go writes, and with no commit yet the top-level entries the setup commit takes (`references/scaffold.md`), even when `Missing files` names them; a value to be asked reads `?` and lists the local branches (or the remotes) | setup is due (step 2): `AGENTS.md` or `CLAUDE.md` missing, no `## Working mode (aegonex 0.4)` heading, or no `@AGENTS.md` line |
| Will move / จะย้าย | the main folder's changed files and `<b>` (the unit starts from it or merges it): `<files> and <b> into .worktrees/t-<slug>; <b> is kept` / `<files> และ <b> ไปที่ .worktrees/t-<slug>; ยังเก็บ <b> ไว้` (`<u>` in place of `t-<slug>` when `<b>` is `aegonex/<u>`); on `<Base>`: `<files> into .worktrees/<u>` / `<files> ไปที่ .worktrees/<u>`; detached: `<files> and <sha> into .worktrees/<u>` / `<files> และ <sha> ไปที่ .worktrees/<u>`; while Base reads `?`, `<b>` is the main folder's branch, and an answer naming it as Base moves the files alone into the step's unit | main folder not clean |
| Read by mistake / อ่านเกินขอบเขต | `<file>: ignore its content` | the file check below found one |

The header row is `| Item | Detail |` / `| เรื่อง | รายละเอียด |`, the first
step's label `First step:` / `ขั้นแรก:`. Paths, commands and commit ids go in
backticks. No emoji or icons. Not shown: the HEAD sha, NOTE and dead-end
counts, and this skill's own words (drift, anchor, tree).

The first step is chosen in this order; the first match wins:
1. a unit folder's status shows an unfinished merge (`UU`, `AA`, `DU`,
   `UD`): finish that merge in `<f>`, naming the files;
2. a unit folder, or the main folder, has changes HANDOFF.md does not
   mention (`HANDOFF.md` and `ROADMAP.md` aside): inspect them, naming the files;
3. the open `m<n>` folder is closed: online (as `aegonex-done` defines it)
   → `when its pull request is merged, tell aegonex-done` (a task may start
   meanwhile); not online → `run aegonex-done` (it lands it);
4. HANDOFF.md names a next step: that step (a session log, if present, may
   sharpen it), unless it names `aegonex-done` for a milestone whose line
   carries `· closed`, or a task that has no branch any more;
5. the current milestone has an unticked step: the first one, its `done when` in plain words;
6. every step ticked and the milestone not closed: run `aegonex-done`;
7. otherwise run `aegonex-plan` (no roadmap, no current milestone, no steps).

The step's unit is its tag, `(M<n>)` → `m<n>` or `(t-<slug>)`, else the
current milestone; a focus the user typed that is not on the roadmap is a
task `t-<slug>` (1 to 3 English words). Changes moved from a branch `<b>` go
to the task `t-<slug>`, slug = `<b>` after its last `/` in `a-z0-9-`, first three words
(`fix/db-race` → `t-db-race`), or to `<u>` when `<b>` is `aegonex/<u>`;
changes on `<Base>` or a detached HEAD go to the step's unit, else to a task
named for them. The first step for moved changes works in that folder. A new
unit whose `<remote>/aegonex/<u>` exists (an old pull request): a task takes
the next free `t-<slug>-2`, `-3`; a milestone stops the go, `by hand: delete
aegonex/m<n> on the host, then git -C "<main>" fetch --prune <remote>`. A
closed unit is never opened: its row sends the user to `aegonex-done`.

One first step, not a menu. When drift makes two candidates plausible, the
first step picks the one the working tree supports and says why in five
words. Anything the user typed beyond the invocation ("start work on auth",
"เริ่มงาน ทำ login ต่อ") is today's focus: it reshapes the first step and is
not permission to start. The preparations the go runs come first in the
first step, joined by `, then`, in this order: `move <files> into
.worktrees/<u>`, `update the main folder`, `set up aegonex` (with `AGENTS.md`
or `CLAUDE.md` missing, `create <files>` instead, naming the missing ones),
`open .worktrees/<u>` or `adopt this folder`. In a harness folder, setup and
move need the main folder: the first step is `start a session in <main> and
run aegonex-init` (the harness may block `<main>`).

Before printing, check the files opened against the Procedure's read list; any
other file means the procedure was left, and the brief still goes out with a `Read by mistake` row.

The question comes last, once, and nothing follows it:
- If your harness has a tool that asks the user a multiple-choice question
  (Claude Code: `AskUserQuestion`), print the brief, then ask with it:
  `Start the first step?` / `เริ่มขั้นแรกเลยไหม?`, options `go` (the first
  step in a few words) and `Not now` / `ไม่ใช่ตอนนี้`; the tool adds the free-text answer itself.
- Otherwise the reply ends with this line, alone, after a blank line:
  `Reply **go** to start, or tell me what to do instead.` /
  `พิมพ์ **go** เพื่อเริ่ม หรือบอกว่าอยากทำอะไรแทน`
- When Base or Remote must be asked (`references/scaffold.md`), that is the
  question instead, asked either way above, its choices as options:
  `Which remote is Remote?` / `Remote คือ remote ไหน?` when Remote is unknown,
  else `Which branch is Base?` / `Base คือ branch ไหน?`. The answer counts as the go.

A Thai user, a handoff that is behind, no question tool:

```
**shop-api · branch fix/cart-total**

| เรื่อง | รายละเอียด |
|---|---|
| งานปัจจุบัน | M3 ตะกร้าสินค้า: เสร็จ 2 จาก 5 ขั้น |
| ครั้งก่อนหยุดที่ | คำนวณส่วนลดใน `src/cart.ts` (2026-09-20) |
| branch ไม่ตรง | ตอนนี้อยู่ `fix/cart-total` แต่ handoff เขียนไว้บน `feat/cart` |
| แก้ค้างอยู่ | `src/tax.ts`: ปัดเศษภาษีเป็นทศนิยม 2 ตำแหน่ง |

**ขั้นแรก:** ดูการแก้ใน `src/tax.ts` ก่อน แล้วค่อยกลับไปทำส่วนลด

พิมพ์ **go** เพื่อเริ่ม หรือบอกว่าอยากทำอะไรแทน
```

### 6. Stop, then act on the answer

No code is read, written or run until the user answers. Any clear yes is go:
go, ok, yes, ได้, โอเค, ลุย, and so is the answer to a Base or Remote question
(it sets that value). `Not now` ends the skill with nothing written. Any other
answer is a new focus: restate the first step in one sentence and proceed with
it. A go missing a value replies with one line naming it and one question, and writes nothing.

On go, in this order (each command its own tool call on one line, git as
`git -C "<absolute folder>" ...` even where the shell already stands):
1. **move**, when `Will move` has rows: steps 1 to 5 of the recipe in
   `references/scaffold.md` (save, restore, switch to `<Base>`).
2. **update**, when `Main folder behind` fired: **Update** as `aegonex-done`
   step 7.4.2 says (`../aegonex-done/SKILL.md`); refused or stopped: go on.
3. **setup**, when the brief has a `Setup` row: `references/scaffold.md`,
   which writes and commits the files on `<Base>` in the main folder.
4. **open** the unit when its folder does not exist yet, as **Open** in
   `AGENTS.md` says; for moved changes, the recipe's steps 7 to 10. A harness
   folder that is detached or on a branch outside `aegonex/*` is adopted
   instead, after `git -C "<here>" worktree prune`: `git -C "<here>" switch aegonex/<u>`
   when that branch exists and no folder holds it, else
   `git -C "<here>" switch -c aegonex/<u> <Base>` (the harness's own branch
   stays); a branch held by another folder is not adopted: the reply names that folder.
5. **reply**: the go part is at most 2 lines, no table or question. First
   `**Opened:** .worktrees/<u>` / `**เปิดแล้ว:** .worktrees/<u>` (an adopted
   folder: its path), then one line of what the go did, one clause per action
   in the order they ran, joined by ` · `: `moved <files> (<b> kept)` /
   `ย้าย <files> แล้ว (ยังเก็บ <b>)`, `updated the main folder` /
   `อัปเดตโฟลเดอร์หลักแล้ว`, `set up: <files>` / `ตั้งค่าแล้ว: <files>`, a failed
   or stopped action named with its first error line quoted, and after a move
   `reopen your editor there` / `เปิด editor ใหม่ที่โฟลเดอร์นี้`. Then the step
   runs under `Leader mode` and its report follows; an inspect step reports,
   from `git -C "<f>" diff HEAD -- <files>` alone (an untracked file: its content),
   what changed and any `AIDEV-NOTE` in it (context lines included), never a
   guess at intent. If the step was `aegonex-plan`, name it and stop: init does not plan.
Init never lands, pushes, opens a pull request, or removes a folder or branch.

## Red flags — stop, you are leaving the procedure

- "I'll just peek at the file for context around the anchor."
- "HANDOFF mentions this test file, let me look at it."
- "There is no ROADMAP, I'll write a quick one so the brief has something."
- "I'll create AGENTS.md now, it is only a template."
- "The change is small, I'll make it in the main folder."
- "The shell already stands in the folder, plain `git` is fine." Git is always `git -C "<folder>"`, after the go too.
- "I need to see the code to propose a good first step."

The brief comes from testimony and git only: code read before go spends context on an unchosen task.

## Quick reference

| Situation | Init does |
|---|---|
| HANDOFF branch ≠ current | `Branch mismatch` row, first step from the current branch |
| Dirty tree HANDOFF ignores | `Uncommitted work` row, first step inspects those files |
| `## Session log` in HANDOFF | `Unfinished session` row; the log sharpens the first step |
| No ROADMAP, or no current milestone | first step is to run `aegonex-plan`; every step ticked: `aegonex-done` |
| No AGENTS.md / CLAUDE.md, or no v0.4 sections | `Missing files` and `Setup` rows; setup after go; a Base or Remote to ask is the question |
| Main folder has changes, or is on a v0.3 branch | `Will move` row; go moves them into `.worktrees/t-<slug>` named for the branch (kept), else the step's unit |
| `m2` closed, its pull request waiting | `Other work` row; plan waits, tasks may start |
| Session runs in a harness-made worktree | go adopts it as the unit folder |
| User adds a focus | the focus reshapes the first step; the question still comes |

## Common mistakes

| Mistake | Instead |
|---|---|
| Creating any file or folder before go | name it in `Missing files`, `Setup` or `Work folder`; create after the answer |
| Counting the handoff commit as drift | the oldest commit after `HEAD:` that includes HANDOFF.md is the handoff, whatever else it touches |
| Editing in the main folder | every step runs in `.worktrees/<u>` |
| Saying the handoff is stale without the evidence | a row with the branch names, commits or files |
| A row that says none, 0 or nothing new | leave the row out |
| Printing the brief inside a code block | plain markdown, so the table renders |
| Offering two or three options | one first step, one question |
| Treating the user's extra words as a go-ahead | they are the focus; the question still ends the brief |
