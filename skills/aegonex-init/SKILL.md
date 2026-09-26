---
name: aegonex-init
description: Use when a work session starts on a project — the first message of the day, "เริ่มงาน", "start work", "where were we", "ต่อจากที่ค้างไว้", "continue from yesterday", "boot" — or when opening a project that has no AGENTS.md, ROADMAP.md or HANDOFF.md yet. Also use when a session resumes after context was compacted or the user mentions a handoff.
license: MIT
metadata:
  author: Aegonex
  version: "0.3.0"
---

# aegonex-init

## Overview

Every session opens through this skill. It rebuilds the working picture from
the state files in the project repo plus git, then hands the user one
decision. It reads. It writes nothing at all before the user answers the
brief's question, and after go only the files it listed as missing.

Core principle: **git is the truth, the files are testimony.** Whenever they
disagree, the disagreement is reported, never silently resolved.

The state files, each with its own owner and rate of change:

| File | Answers | Written by |
|---|---|---|
| `AGENTS.md` | stack, commands, rules, session ritual | init creates it once; the user edits it |
| `ROADMAP.md` | goal, milestones, steps with `done when` | `aegonex-plan` |
| `HANDOFF.md` | where the last session stopped, the next step, dead ends | `aegonex-exit` |
| `CLAUDE.md` | one line pointing at `AGENTS.md` | init creates it once |

Spot-level state lives in the code as anchor comments: `AIDEV-TODO:`
(pending work at that spot) and `AIDEV-NOTE:` (an invariant that must
survive edits). Sibling verbs: `aegonex-plan` writes the roadmap,
`aegonex-note` records a decision or dead end the moment it happens,
`aegonex-exit` closes a session, `aegonex-done` closes a milestone.

## When to use

- The user opens a session: "เริ่มงาน", "start", "where were we", "ต่อจากเมื่อวาน".
- A project has none, or only some, of the state files.
- Context was just compacted and the working picture is gone.

Not for: ending a session (`aegonex-exit`), planning (`aegonex-plan`), or
mid-session questions about code.

## Language

Every reply is in the user's language: labels, content, the question and its
options (`go` stays `go`). That is the language of the user's message; when
they typed only the skill's name, the language of the conversation so far;
else the language of `HANDOFF.md` and `ROADMAP.md`; else English. This skill
gives labels in English and Thai; for another language, translate the
English. Paths, commit subjects and quoted notes stay as they are.

## Procedure

Run the steps in order and without commentary: the brief is the whole reply.
Before go the procedure reads only: the four state files, manifests
(`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml` and the like),
`README.md`, `CONTRIBUTING.md`, and this skill's own files. `git diff` on a
file that `git status` listed is git output and is allowed; opening `src/…`
or any other code file is not.

### 1. Git facts

```bash
git rev-parse --show-toplevel        # project root; all paths below are relative to it
git branch --show-current
git rev-parse --short HEAD
git status --short                   # uncommitted work
git log --oneline -5
```

### 2. The state files at the project root

| File | Missing | Present |
|---|---|---|
| `AGENTS.md` | derive its content now (`references/scaffold.md`), name it in the brief's `Missing files` row, create it only after go | read it if the harness did not already load it |
| `CLAUDE.md` | same as `AGENTS.md`; if the file exists without the pointer line, the line is appended after go | nothing |
| `ROADMAP.md` | name it in the `Missing files` row: `aegonex-plan` creates it | read it: the current milestone is the first unticked `- [ ] M…` line; count its `- [ ]`/`- [x]` steps (the `docs:` line is not a step) |
| `HANDOFF.md` | name it in the `Missing files` row: `aegonex-exit` creates it when the session ends; drift checks that need it are skipped | read it |

Init never creates `ROADMAP.md` or `HANDOFF.md`, never asks planning
questions, and never edits a file that exists, except to append the pointer
line to `CLAUDE.md` after go.

### 3. Anchors

```bash
grep -rn --exclude-dir={node_modules,.git,dist,build,vendor,target} --exclude={AGENTS.md,CLAUDE.md,ROADMAP.md,HANDOFF.md} -E "AIDEV-(TODO|NOTE)" .
```

Keep the TODOs as `file:line — text`; NOTEs do not appear in the brief.
The grep line is the whole anchor. The file is not opened for context, not
with `cat`, `head`, `sed` or a file-read tool; context arrives after go.

### 4. Drift checks (required)

Each check that is true becomes a row of the brief and names its evidence:
the two branch names, the commits, the files, the line count. "HANDOFF looks
out of date" without evidence is not a finding. A check that is false leaves
no trace in the brief.

| Check | How |
|---|---|
| Branch mismatch | `Branch:` in HANDOFF.md ≠ `git branch --show-current` |
| Commits after the handoff | `H` = the sha after `HEAD:` in HANDOFF.md. If `git cat-file -e H` succeeds, `git log --oneline --name-only H..HEAD`; if it fails (rebase, squash, shallow clone) or there is no `HEAD:` line, `git log --oneline --name-only --since="<HANDOFF date> 00:00"` (a bare date means today's time of day). From that list drop the oldest commit whose files include `HANDOFF.md`: that is the handoff commit, whatever else it touches. Also drop commits whose only files are `HANDOFF.md` and/or `ROADMAP.md`. Whatever remains is drift; quote it, nothing older. |
| Unrecorded work | `git status --short` lists files HANDOFF.md does not mention. Characterise each with `git diff --stat` or `git diff <file>` in a few words (what changed), not by opening the file. |
| Session ended without exit | HANDOFF.md contains `## Session log`. Exit always removes that section, so its presence means the last session (or this one, before a compaction) never reached exit. Count its `- ` lines; they are testimony for the first step. |
| Oversized handoff | HANDOFF.md is longer than 60 lines |

### 5. The brief

The reader may not know git or this skill's words. The brief is a bold
title, one table, the bold first step and the question. Print it as
markdown, not inside a code block, so the table renders:

```
**<project> · branch <branch>**

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**First step:** <one concrete action>
```

Rows come in this order. A row appears only when it has something to say:
no row reads "none", "0" or "-", and a fact already in the table is not
repeated. With no rows, the table is left out.

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| Current work / งานปัจจุบัน | `<M> <name>: <done> of <total> steps done` / `<M> <name>: เสร็จ <done> จาก <total> ขั้น` | `ROADMAP.md` has a current milestone |
| Last stopped at / ครั้งก่อนหยุดที่ | HANDOFF's Stopped at in a few words, its date in brackets | `HANDOFF.md` has a Stopped at |
| Unfinished session / session ก่อนไม่ได้ปิด | `<n> notes left; aegonex-exit never ran` / `มีบันทึกค้าง <n> บรรทัด ไม่ได้ปิดด้วย aegonex-exit` | `## Session log` is present |
| Branch mismatch / branch ไม่ตรง | `on <current>, handoff written on <branch>` / `ตอนนี้อยู่ <current> แต่ handoff เขียนไว้บน <branch>` | the branches differ |
| New commits / commit ใหม่ | `<sha> <subject>` for each commit after the handoff, at most 3, then `+<n> more` | drift commits remain |
| Uncommitted work / แก้ค้างอยู่ | `<file>: <what changed>` for files HANDOFF does not mention, at most 3 | there are such files |
| TODO in code / TODO ในโค้ด | `<file:line> <text>`, at most 3 | a TODO sits in a file no other row names |
| Handoff too long / handoff ยาวเกิน | `<n> lines, limit 60` | `HANDOFF.md` is over 60 lines |
| Missing files / ไฟล์ที่ยังไม่มี | each missing state file and what makes it: `AGENTS.md`, `CLAUDE.md` after go; `ROADMAP.md` by aegonex-plan; `HANDOFF.md` by aegonex-exit when the session ends | a state file is missing |
| Read by mistake / อ่านเกินขอบเขต | `<file>: ignore its content` | the file check below found one |

The header row is `| Item | Detail |` / `| เรื่อง | รายละเอียด |`, the first
step's label `First step:` / `ขั้นแรก:`. Paths, commands and commit ids go in
backticks. No emoji or icons. Not shown: the HEAD sha, NOTE and dead-end
counts, and this skill's own words (drift, anchor, tree).

The first step is chosen in this order; the first match wins:
1. the working tree has changes HANDOFF.md does not mention: inspect them,
   naming the files;
2. HANDOFF.md names a next step: that step (a session log, if present, may
   sharpen it);
3. ROADMAP.md has an unticked step in the current milestone: the first one,
   with its `done when` in plain words;
4. otherwise run `aegonex-plan` (no roadmap, or the current milestone has no
   unticked step).

One first step, not a menu. When drift makes two candidates plausible, the
first step picks the one the working tree supports and says why in five
words. Anything the user typed beyond the invocation ("start work on auth",
"เริ่มงาน ทำ login ต่อ") is today's focus: it reshapes the first step and is
not permission to start. With `AGENTS.md`/`CLAUDE.md` missing, the first step
reads `create <files>, then <the step chosen above>`.

Before printing, check the list of files opened: only the four state files,
manifests, `README.md`, `CONTRIBUTING.md` and this skill's own files.
Anything else means the procedure was left; the brief still goes out, with
the `Read by mistake` row.

The question comes last, once, and nothing follows it:
- If your harness has a tool that asks the user a multiple-choice question
  (Claude Code: `AskUserQuestion`), print the brief, then ask with it:
  `Start the first step?` / `เริ่มขั้นแรกเลยไหม?`, options `go` (the first
  step in a few words) and `Not now` / `ไม่ใช่ตอนนี้`. The tool adds a
  free-text answer by itself.
- Otherwise the reply ends with this line, alone, after a blank line:
  `Reply **go** to start, or tell me what to do instead.` /
  `พิมพ์ **go** เพื่อเริ่ม หรือบอกว่าอยากทำอะไรแทน`

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
go, ok, yes, ได้, โอเค, ลุย. `Not now` ends the skill with nothing written.
Any other answer is a new focus: restate the first step in one sentence and
proceed with it.

On go with `AGENTS.md`/`CLAUDE.md` in `Missing files`, write exactly those
files from `references/scaffold.md` and say so in one line
(`created: <files>` / `สร้างแล้ว: <files>`); if the step was
`aegonex-plan`, name it and stop: init does not plan.

## Red flags — stop, you are leaving the procedure

- "I'll just peek at the file for context around the anchor."
- "HANDOFF mentions this test file, let me look at it."
- "`head -20` is hardly reading it."
- "There is no ROADMAP, I'll write a quick one so the brief has something."
- "I'll create AGENTS.md now, it is only a template."
- "I need to see the code to propose a good first step."

The brief is built from testimony and git only. Reading code before go
spends the user's context on a task they have not chosen yet, and a file
created before go lands in a repo the user may not want it in.

## Quick reference

| Situation | Init does |
|---|---|
| All files present, git agrees | two or three rows, first step from HANDOFF |
| HANDOFF branch ≠ current | `Branch mismatch` row, first step from the current branch |
| Dirty tree HANDOFF ignores | `Uncommitted work` row, first step inspects those files |
| `## Session log` in HANDOFF | `Unfinished session` row; the log sharpens the first step |
| No ROADMAP, or current milestone fully ticked | first step is to run `aegonex-plan` |
| No AGENTS.md / CLAUDE.md | `Missing files` row; created after go, nothing else created |
| User adds a focus | the focus reshapes the first step; the question still comes |
| User typed only the skill's name | the conversation's language, else the state files', else English |

## Common mistakes

| Mistake | Instead |
|---|---|
| Creating any file before go | name it in `Missing files`; create after the answer |
| Creating ROADMAP.md or HANDOFF.md at all | plan and exit own them; init only names them |
| Counting the handoff commit as drift | the oldest commit after `HEAD:` that includes HANDOFF.md is the handoff, whatever else it touches |
| Counting the state files' own text as anchors | the grep excludes the four state files |
| Saying the handoff is stale without the evidence | a row with the branch names, commits or files |
| A row that says none, 0 or nothing new | leave the row out |
| Printing the brief inside a code block | plain markdown, so the table renders |
| Offering two or three options | one first step, one question |
| The question inside a longer line, or text after it | the question alone, last |
| English labels for a Thai user | the user's language, labels included |
| Treating the user's extra words as a go-ahead | they are the focus; the question still ends the brief |
