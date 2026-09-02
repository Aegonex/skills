---
name: aegonex-init
description: Use when a work session starts on a project — the first message of the day, "เริ่มงาน", "start work", "where were we", "ต่อจากที่ค้างไว้", "continue from yesterday", "boot" — or when opening a project that has no AGENTS.md, ROADMAP.md or HANDOFF.md yet. Also use when a session resumes after context was compacted or the user mentions a handoff.
license: MIT
metadata:
  author: Aegonex
  version: "0.1.0"
---

# aegonex-init

## Overview

Every session opens through this skill. It rebuilds the working picture from
three files in the project repo plus git, then hands the user one decision.

Core principle: **git is the truth, the files are testimony.** Whenever they
disagree, the disagreement is reported, never silently resolved.

The three files, each with its own rate of change:

| File | Answers | Changes |
|---|---|---|
| `AGENTS.md` | stack, commands, rules, session ritual | rarely |
| `ROADMAP.md` | what we are building, why, which milestone is current | per milestone |
| `HANDOFF.md` | where the last session stopped, the next step, dead ends | every session |

`CLAUDE.md` is only a pointer to `AGENTS.md`. Spot-level state lives in the
code as anchor comments: `AIDEV-TODO:` (pending work at that spot) and
`AIDEV-NOTE:` (an invariant that must survive edits).

## When to use

- The user opens a session: "เริ่มงาน", "start", "where were we", "ต่อจากเมื่อวาน".
- A project has none, or only some, of the three files.
- Context was just compacted and the working picture is gone.

Not for: ending a session (that is `aegonex-exit`), or mid-session questions
about code.

## Procedure

Run the steps in order. The whole procedure reads the three files, runs the
git commands listed in steps 1 and 4, and runs one grep. It opens no source
file: `git diff` output on a file that `git status` listed is git output and
is allowed; opening `src/…` or any other code file is not, until the user
says go.

### 1. Git facts

```bash
git rev-parse --show-toplevel        # project root; all paths below are relative to it
git branch --show-current
git rev-parse --short HEAD
git status --short                   # uncommitted work
git log --oneline -5
```

### 2. Find the three files at the project root

| Found | Do |
|---|---|
| none of the three | Read `references/scaffold.md` and follow it. Then continue at step 3 with the fresh files. |
| some missing | Create only the missing ones from `assets/` (see `references/scaffold.md`, section "Partial"). Note them in the brief. Continue. |
| all three | Read `HANDOFF.md`, then `ROADMAP.md`. `AGENTS.md` is already loaded by most agents; read it only if it was not. |

### 3. Anchors

```bash
grep -rn --exclude-dir={node_modules,.git,dist,build,vendor,target} -E "AIDEV-(TODO|NOTE|QUESTION)" .
```

Count TODOs and NOTEs. Keep the three most relevant TODOs as `file:line — text`.
The grep line is the whole anchor. The file is not opened for context, not
with `cat`, `head`, `sed` or a file-read tool; context arrives after `go?`.

### 4. Drift checks (required)

Each check that is true becomes one line under ⚠️ in the brief. If none is
true the line says `none`.

| Check | How |
|---|---|
| Branch mismatch | `Branch:` in HANDOFF.md ≠ `git branch --show-current` |
| Commits after the handoff | `git log --oneline <HEAD-in-HANDOFF>..HEAD -- . ':!HANDOFF.md' ':!ROADMAP.md'` is non-empty. Commits that only touch `HANDOFF.md`/`ROADMAP.md` are the handoff being committed and are not drift. If HANDOFF.md has no HEAD line, `git log --oneline --since="<HANDOFF date>" -- . ':!HANDOFF.md' ':!ROADMAP.md'` lists them; quote that list, nothing older. |
| Unrecorded work | `git status --short` lists files that HANDOFF.md does not mention. Characterise each with `git diff --stat` or `git diff <file>` in a few words (what changed), not by opening the file. |
| Oversized handoff | HANDOFF.md is longer than 60 lines (the last `aegonex-exit` was sloppy) |

A drift line names the evidence: the two branch names, the newer commits, the
unmentioned files. "HANDOFF looks out of date" without evidence is not a drift
line.

### 5. The brief

Print exactly this shape, then stop and wait. Fifteen lines at most, one
question at the end, nothing before 📍 and nothing after the question.

```
📍 <project> · <branch> · HEAD <sha> · tree: clean | <n> modified: <files, max 3>
🧭 ROADMAP: <current milestone> — <done>/<total> steps
🔁 HANDOFF (<date>, <branch>): stopped at <…> · next: <…> · dead ends: <n>
📌 Anchors: <n> TODO · <n> NOTE — <top 3 TODOs as file:line — text>
⚠️ Drift: <one line per finding with evidence> | none
▶️ First step: <one concrete action> — go?
```

Rules for the brief:
- One first step, not a menu. When drift makes two candidates plausible (the
  handoff says X, the working tree shows Y), the ⚠️ line states both and
  the ▶️ line picks the one the working tree supports, saying why in five
  words.
- Anything the user typed beyond the invocation ("start work on auth",
  "เริ่มงาน ทำ login ต่อ") is today's focus: it shapes the ▶️ line. It is not
  permission to start.
- On a fresh project the order is: the six lines (📍 ends with `created:
  <files>`, 🔁 reads `HANDOFF: fresh start`, ▶️ reads `answer the three
  questions below, then start M1 — go?`), then the three scaffold questions,
  then the closing line. The brief is never replaced by prose.
- The final line of the message, after the question, names the closer in
  the user's language, once: `จบงานเรียก aegonex-exit` when the user writes
  Thai, `end with aegonex-exit` otherwise.

### 6. Stop

No code is read, written or run until the user answers the question. If the
answer changes the plan, update the ▶️ line in one sentence and proceed.

Before printing the brief, check the list of files opened. It contains only
`AGENTS.md`, `ROADMAP.md`, `HANDOFF.md`, manifests (`package.json` and the
like) and this skill's own files. Anything else means the procedure was
left; the brief still goes out, and the ⚠️ line gains
`init opened <file> — ignore its content, not part of the brief`.

## Red flags — stop, you are leaving the procedure

- "I'll just peek at the file for context around the anchor."
- "HANDOFF mentions this test file, let me look at it."
- "`head -20` is hardly reading it."
- "It is a tiny scaffold, reading it costs nothing."
- "I need to see the code to propose a good first step."

The brief is built from testimony and git only. Reading code before `go?`
spends the user's context on a task they have not chosen yet, and the
first step is chosen from the working tree, not from code comprehension.

## Quick reference

| Situation | Init does |
|---|---|
| Three files present, git agrees | brief, propose HANDOFF's next step |
| HANDOFF branch ≠ current | ⚠️ with both names, propose from the current branch |
| Dirty tree HANDOFF ignores | ⚠️ listing the files, propose inspecting them first |
| No files at all | scaffold (`references/scaffold.md`), ask the 3 scaffold questions, brief |
| User adds a focus | focus drives ▶️, still ends with `go?` |

## Common mistakes

| Mistake | Instead |
|---|---|
| Opening source files before the user says go | the three files, the git commands of steps 1 and 4, one grep; `git diff` on a dirty file is enough to describe it |
| Saying the handoff is stale without the evidence | ⚠️ line with branch names / commit list / file list |
| Offering two or three options and three questions | one ▶️ step, one `go?` |
| On a fresh project, asking which UI library or which features to build | those belong to `ROADMAP.md` later; ask only the three scaffold questions |
| Treating the user's extra words as a go-ahead | they are the focus; the question still ends the brief |
| Skipping the anchor grep because the handoff already lists work | anchors are the spot-level truth; the handoff may be stale |
| Forgetting to name `aegonex-exit` | it is the last line of every brief |
