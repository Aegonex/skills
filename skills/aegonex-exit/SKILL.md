---
name: aegonex-exit
description: Use when a work session is ending or must be handed off — "ปิดงาน", "พอแค่นี้", "จบวันนี้", "wrap up", "done for today", "handoff" — or when the context is getting heavy and the user wants to compact or open a new session. Also use before switching to another AI agent or another machine.
license: MIT
metadata:
  author: Aegonex
  version: "0.2.0"
---

# aegonex-exit

## Overview

Every session closes through this skill. It writes the state that
`aegonex-init` will read next time: `ROADMAP.md` reconciled, `HANDOFF.md`
rewritten (or created, on a project's first exit), anchor comments tidied.
It is the only owner of `HANDOFF.md`; `aegonex-note` may append lines to
its `## Session log` during the session, and this skill folds them in.

Core principle: **everything written comes from evidence the session
produced** — a commit id, a test that ran here and passed, a diff, a
session-log line, or the user's own words. Nothing is ticked, claimed or
asserted from memory of what "should" have happened.

Two things it never does: it never commits on its own, and it never writes
any part of a secret. Both have their own sections below because agents
without this skill did both.

## When to use

- The user ends the session: "ปิดงาน", "พอแค่นี้", "wrap up", "done for today".
- The context is heavy and a compaction or a new session is coming.
- The work moves to another agent or machine.

Not for: starting a session (`aegonex-init`), recording one fact mid-task
(`aegonex-note`), or closing a milestone (`aegonex-done`).

## Procedure

### 1. Git facts

```bash
git rev-parse --show-toplevel
git branch --show-current
git rev-parse --short HEAD
git status --short
git log --oneline -5
git diff --stat
git diff <file>        # once per file in git status; git output, not a file read
```

### 2. Session facts

Start with `## Session log` in `HANDOFF.md` if it exists: every line there
is a fact already recorded (decision, dead end, environment fact). Then,
from the session itself, list:
- work completed, each with its evidence: commit id, test command that ran
  here and its result, or the user's words
- work in flight: which files, what is missing before it is done
- decisions the user made (what, why)
- dead ends: what was tried, why it failed, so nobody retries it
- environment facts learned: commands that need flags or variables, things
  not visible in git
- documents created this session: new files under `docs/` or the
  `Scratch:` directory of `AGENTS.md`, from `git status --short`

A fact about the environment is recorded as the session showed it. No
probe is run now to "verify" it, and no check is claimed that did not run.

### 3. Reconcile ROADMAP.md

If the file does not exist, skip this step and print
`ROADMAP: none — aegonex-plan creates it` in the brief.

| Situation | Do |
|---|---|
| step whose `done when` was observed this session (the command ran here and passed, the behaviour was seen, the user said so) | tick it `[x]` |
| step with uncommitted or partial code | leave `[ ]`; make sure ` (in progress)` is at the end of the line exactly once |
| decision made today (from the log or the session) | add under Decisions: `YYYY-MM-DD — <decision> (<why>)` |
| new step discovered | add under its milestone, with a `done when` |
| document created this session | add its path to the current milestone's `docs:` line (create the line if missing) |
| milestone whose steps are all ticked | tick the milestone line |

Change nothing else. The file stays under two pages.

### 4. Anchors

```bash
grep -rn --exclude-dir={node_modules,.git,dist,build,vendor,target} --exclude={AGENTS.md,CLAUDE.md,ROADMAP.md,HANDOFF.md} -E "AIDEV-(TODO|NOTE)" .
```

- `AIDEV-TODO` whose work finished this session (evidence as above): delete
  that comment line.
- Work stopped mid-way with no anchor at the spot: add one line
  `AIDEV-TODO: <what is missing>` there.
- An anchor whose text a decision made wrong (a number, a name): update the
  text.

Only comment lines change. No other line of code is touched by this skill.

### 5. Rewrite HANDOFF.md

Overwrite the whole file from `assets/HANDOFF.md`, or create it from the
template when it does not exist: a project's first exit is the normal path,
not an exception. Never append to the old one; the old content is
superseded, and the commit history keeps it. The rewrite has no
`## Session log`: its lines went into the sections below in step 2.

Required slots:
- `# HANDOFF — <YYYY-MM-DD>`
- `Branch: <git branch --show-current> · HEAD: <git rev-parse --short HEAD>`
  (the HEAD at writing time; the commit that follows is the handoff
  commit, and `aegonex-init` ignores it whatever else it touches)
- **Stopped at**: one line per file in `git status --short` — what changed
  and whether it is intentionally uncommitted — plus the state of the work
  in flight; a test not re-run after an edit says `not re-run`
- **Next step**: one action, the first thing the next session does
- **Dead ends**: from step 2
- **Notes for the next session**: environment facts from step 2
- **Suggested skills**: `aegonex-init` first, then whatever the next step
  needs

Limits: 60 lines. Paths and commit ids, not pasted code or commit messages.

### 6. Secret scan

Before saving any file, read the text about to be written and look for
credentials: values after `KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `Bearer`,
prefixes like `sk-`, `ghp_`, `xox`, `AKIA`, `.env` values, and any random
string longer than 16 characters. Each one becomes `<redacted>` or a
description such as `<the prod JWT secret>`; the fact around it stays
("the shell exports the prod JWT secret by mistake; run tests with
`JWT_SECRET=dev`"). After saving, run exactly:

```bash
grep -nEi 'KEY|TOKEN|SECRET|PASSWORD|Bearer|sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' HANDOFF.md ROADMAP.md AGENTS.md
```

and read every hit: a variable name is fine, a value is not. A prefix, a
suffix, a "first few characters" of a secret is a secret.

### 7. Verify against git

Run `git status --short` again. Every path it lists appears in Stopped at;
if one is missing, add it. `wc -l HANDOFF.md` is at most 60. The only files
changed by this skill are `HANDOFF.md`, `ROADMAP.md` and anchor comment
lines; anything else in the diff is reported in the `Unrecorded:` line.

### 8. The brief

Print exactly this shape, then stop.

```
Repo: <project> · <branch> · HEAD <sha> · tree: clean | <n> modified: <files>
ROADMAP: <current milestone> — <done>/<total> · ticked today <n> · decisions +<n> | none — aegonex-plan creates it
HANDOFF rewritten | created (<date>): stopped at <…> · next: <…> · dead ends: <n>
Anchors: <n> removed · <n> added · <n> open
Unrecorded: <paths in git status missing from HANDOFF, or other files this skill touched> | none
Commit? `git add <files> && git commit -m "<message>"` — go?
```

Rules:
- Each line starts with its label in plain text. No emoji, icon or bullet
  precedes a label.
- The `Commit?` line lists the exact files (`HANDOFF.md`, `ROADMAP.md`,
  files with anchor edits, and the user's in-flight files only if they
  said the work is ready) with a message under 72 characters. It is a
  question. The command is not run.
- If the user's message itself asked for the commit ("commit ด้วย",
  "commit it"), that is the authorisation: run the commit after step 7 and
  the `Commit?` line becomes `Committed <sha>: <files>` with no question.
- The final line names the next entry, in the user's language, once:
  `session หน้าเปิดด้วย aegonex-init` / `next session: start with aegonex-init`.
  When the user mentioned context, compaction or a new session, the line
  is a command to copy: `พิมพ์ /compact แล้วเรียก aegonex-init` /
  `type /compact, then run aegonex-init` (or open a new session and run it).
- No project files exist (never initialised): still create `HANDOFF.md`
  from the template, skip ROADMAP, and the final line adds that
  `aegonex-init` will scaffold the rest.

## Never commit on your own

The files are on disk the moment they are written; nothing is lost by not
committing. Whether and what to commit is the user's decision, asked in the
`Commit?` line. Agents without this skill committed anyway; their reasons:

| Excuse | Reality |
|---|---|
| "A WIP commit keeps the day's work safe" | The work is already on disk. A WIP commit puts unfinished code into history the user did not choose. |
| "Committing only HANDOFF.md and ROADMAP.md is harmless" | It is still a commit the user did not ask for, and it hides the question. |
| "The user said close the work, that includes saving" | Closing = writing the files. Saving to history = the user's word, in the `Commit?` line. |
| "The user always says yes anyway" | Then the answer costs one word. |

## Never probe, never tick on hope

| Excuse | Reality |
|---|---|
| "I need a passing test to tick this" | A run now is a new task. Tick only what ran during the session; otherwise leave `[ ]` and write `not re-run` in Stopped at. |
| "I'll check the environment quickly to confirm the note" | Record what the session showed. Probing now installs things and changes the tree. |
| "The code exists, so the step is done" | Evidence: a commit, a run here, or the user's word. Existence is not evidence. |

## Never write a secret

| Excuse | Reality |
|---|---|
| "Only the prefix, it identifies the key" | A prefix narrows the search space; it is a leak. |
| "It is already in the user's shell" | The shell is not committed to a public repo. HANDOFF.md may be. |
| "The note is useless without the value" | The note is about *which* variable and *what to use instead*; the value adds nothing. |

## Red flags — stop, you are leaving the procedure

- "Let me commit this so nothing is lost."
- "Let me run the tests so I can tick it."
- "I'll write the first characters of the token so they can find it."
- "I'll tick this step, the code is basically done."
- "I'll fix that small bug while I'm in the file." (only comment lines)
- `npm install`, `npx`, `pytest`, `cargo test` or any runner in a command.

## Quick reference

| Situation | Exit does |
|---|---|
| normal end of session | steps 1–8, `Commit?` asks about the commit |
| "context is heavy" mid-task | same; next step = continue the current work; final line gives the `/compact` command |
| user asked for the commit in the same message | steps 1–8, commit after step 7, `Commit?` becomes `Committed <sha>` |
| `## Session log` present | its lines become Decisions, Dead ends, Notes; the rewrite drops the section |
| never initialised (no state files) | HANDOFF.md created from template, no ROADMAP, final line points to `aegonex-init` |
| step already marked `(in progress)` | the suffix stays, once |
| nothing changed this session | HANDOFF.md still rewritten with today's date and the same next step |

## Common mistakes

| Mistake | Instead |
|---|---|
| HANDOFF without `HEAD:` | `aegonex-init` uses it to list the commits made after the handoff |
| Ticking a step because the code exists | evidence: commit, test run here, or the user's word |
| Running a test or an install to get evidence | record `not re-run`; the next session runs it |
| Appending today's notes under the old handoff | overwrite; the old one lives in git history |
| Pasting the diff or the commit message into HANDOFF | the path and the commit id |
| Leaving a completed `AIDEV-TODO` in the code | delete the comment line |
| Ending with a summary instead of the brief | the six lines, then the `Commit?` question, then the final line |
