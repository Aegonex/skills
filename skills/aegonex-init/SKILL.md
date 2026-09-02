---
name: aegonex-init
description: Use when a work session starts on a project — the first message of the day, "เริ่มงาน", "start work", "where were we", "ต่อจากที่ค้างไว้", "continue from yesterday", "boot" — or when opening a project that has no AGENTS.md, ROADMAP.md or HANDOFF.md yet. Also use when a session resumes after context was compacted or the user mentions a handoff.
license: MIT
metadata:
  author: Aegonex
  version: "0.2.0"
---

# aegonex-init

## Overview

Every session opens through this skill. It rebuilds the working picture from
the state files in the project repo plus git, then hands the user one
decision. It reads. It never modifies a file that exists, and it writes
nothing at all before the user answers the brief's question.

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

## Procedure

Run the steps in order. Before `go?` the procedure reads only: the four
state files, manifests (`package.json`, `pyproject.toml`, `go.mod`,
`Cargo.toml` and the like), `README.md`, `CONTRIBUTING.md`, and this
skill's own files. `git diff` on a file that `git status` listed is git
output and is allowed; opening `src/…` or any other code file is not.

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
| `AGENTS.md` | derive its content now (`references/scaffold.md`), list it under `missing:` in the brief, create it only after go | read it if the harness did not already load it |
| `CLAUDE.md` | same as `AGENTS.md`; if the file exists without the pointer line, the line is appended after go | nothing |
| `ROADMAP.md` | the `ROADMAP:` line reads `none — aegonex-plan creates it` | read it: the current milestone is the first unticked `- [ ] M…` line; count its `- [ ]`/`- [x]` steps (the `docs:` line is not a step) |
| `HANDOFF.md` | the `HANDOFF:` line reads `none — the first aegonex-exit creates it`; drift checks that need it are skipped | read it |

Init never creates `ROADMAP.md` or `HANDOFF.md`, never asks planning
questions, and never edits a file that exists.

### 3. Anchors

```bash
grep -rn --exclude-dir={node_modules,.git,dist,build,vendor,target} --exclude={AGENTS.md,CLAUDE.md,ROADMAP.md,HANDOFF.md} -E "AIDEV-(TODO|NOTE)" .
```

Count TODOs and NOTEs. Keep the three most relevant TODOs as `file:line — text`.
The grep line is the whole anchor. The file is not opened for context, not
with `cat`, `head`, `sed` or a file-read tool; context arrives after `go?`.

### 4. Drift checks (required)

Each check that is true becomes one line under `Drift:` in the brief. If none
is true the line says `none`. A drift line names its evidence: the two
branch names, the commit list, the file list, the line count. "HANDOFF looks
out of date" without evidence is not a drift line.

| Check | How |
|---|---|
| Branch mismatch | `Branch:` in HANDOFF.md ≠ `git branch --show-current` |
| Commits after the handoff | `H` = the sha after `HEAD:` in HANDOFF.md. If `git cat-file -e H` succeeds, `git log --oneline --name-only H..HEAD`; if it fails (rebase, squash, shallow clone) or there is no `HEAD:` line, `git log --oneline --name-only --since="<HANDOFF date> 00:00"` (a bare date means today's time of day). From that list drop the oldest commit whose files include `HANDOFF.md`: that is the handoff commit, whatever else it touches. Also drop commits whose only files are `HANDOFF.md` and/or `ROADMAP.md`. Whatever remains is drift; quote it, nothing older. |
| Unrecorded work | `git status --short` lists files HANDOFF.md does not mention. Characterise each with `git diff --stat` or `git diff <file>` in a few words (what changed), not by opening the file. |
| Session ended without exit | HANDOFF.md contains `## Session log`. Exit always removes that section, so its presence means the last session (or this one, before a compaction) never reached exit. Count its `- ` lines; they are testimony for the first step. |
| Oversized handoff | HANDOFF.md is longer than 60 lines |

### 5. The brief

Print exactly this shape, then stop and wait. Fifteen lines at most, one
question at the end, nothing before `Repo:` and nothing after the question
except the closing line.

```
Repo: <project> · <branch> · HEAD <sha> · tree: clean | <n> modified: <files, max 3> [· missing: <files>]
ROADMAP: <current milestone> — <done>/<total> steps | none — aegonex-plan creates it
HANDOFF (<date>, <branch>): stopped at <…> · next: <…> · dead ends: <n> | none — the first aegonex-exit creates it
Anchors: <n> TODO · <n> NOTE — <top 3 TODOs as file:line — text>
Drift: <one line per finding with evidence> | none
First step: <one concrete action> — go?
```

Rules for the brief:
- Each line starts with its label in plain text. No emoji, icon or bullet
  precedes a label.
- `First step:` is chosen in this order; the first match wins:
  1. the working tree has changes HANDOFF.md does not mention: inspect
     them, naming the files;
  2. HANDOFF.md names a next step: that step (a session log, if present,
     may sharpen it: quote the log line);
  3. ROADMAP.md has an unticked step in the current milestone: the first
     one, with its `done when`;
  4. otherwise `run aegonex-plan` (no roadmap, or the current milestone has
     no unticked step).
- One first step, not a menu. When drift makes two candidates plausible,
  the `Drift:` line states both and `First step:` picks the one the
  working tree supports, saying why in five words.
- Anything the user typed beyond the invocation ("start work on auth",
  "เริ่มงาน ทำ login ต่อ") is today's focus: it reshapes `First step:`. It
  is not permission to start.
- Missing `AGENTS.md`/`CLAUDE.md`: `Repo:` ends with `missing: <files>` and
  `First step:` reads `create <files>, then <the step chosen above> — go?`
  (with no roadmap: `create <files>, then run aegonex-plan — go?`).
- The closing line, after the question, names the closer in the user's
  language, once: `จบงานเรียก aegonex-exit` when the user writes Thai,
  `end with aegonex-exit` otherwise.

### 6. Stop, then act on the answer

No code is read, written or run until the user answers the question. If the
answer changes the plan, update `First step:` in one sentence and proceed.

On go with files under `missing:`, write exactly those files from
`references/scaffold.md`, say `created: <files>` in one line, and if the
step was `run aegonex-plan`, name it and stop: init does not plan.

Before printing the brief, check the list of files opened. It contains only
the four state files, manifests, `README.md`, `CONTRIBUTING.md` and this
skill's own files. Anything else means the procedure was left; the brief
still goes out, and the `Drift:` line gains
`init opened <file> — ignore its content, not part of the brief`.

## Red flags — stop, you are leaving the procedure

- "I'll just peek at the file for context around the anchor."
- "HANDOFF mentions this test file, let me look at it."
- "`head -20` is hardly reading it."
- "There is no ROADMAP, I'll write a quick one so the brief has something."
- "I'll create AGENTS.md now, it is only a template."
- "I need to see the code to propose a good first step."

The brief is built from testimony and git only. Reading code before `go?`
spends the user's context on a task they have not chosen yet, and a file
created before `go?` lands in a repo the user may not want it in.

## Quick reference

| Situation | Init does |
|---|---|
| All files present, git agrees | brief, propose HANDOFF's next step |
| HANDOFF branch ≠ current | `Drift:` with both names, propose from the current branch |
| Dirty tree HANDOFF ignores | `Drift:` listing the files, propose inspecting them first |
| `## Session log` in HANDOFF | `Drift:` names the session that ended without exit and the line count; the log sharpens the first step |
| No ROADMAP, or current milestone fully ticked | `First step:` is `run aegonex-plan` |
| No AGENTS.md / CLAUDE.md | `missing:` in `Repo:`, created after go, nothing else created |
| User adds a focus | focus reshapes `First step:`, still ends with `go?` |

## Common mistakes

| Mistake | Instead |
|---|---|
| Creating any file before `go?` | list it under `missing:`; create after the answer |
| Creating ROADMAP.md or HANDOFF.md at all | plan and exit own them; init only names them |
| Counting the handoff commit as drift | the oldest commit after `HEAD:` that includes HANDOFF.md is the handoff, whatever else it touches |
| Counting the state files' own text as anchors | the grep excludes the four state files |
| Saying the handoff is stale without the evidence | `Drift:` line with branch names / commit list / file list |
| Offering two or three options | one `First step:`, one `go?` |
| Treating the user's extra words as a go-ahead | they are the focus; the question still ends the brief |
| Forgetting to name `aegonex-exit` | it is the last line of every brief |
