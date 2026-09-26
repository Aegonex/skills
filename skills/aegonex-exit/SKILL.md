---
name: aegonex-exit
description: Use when a work session is ending or must be handed off — "ปิดงาน", "พอแค่นี้", "จบวันนี้", "wrap up", "done for today", "handoff" — or when the context is getting heavy and the user wants to compact or open a new session. Also use before switching to another AI agent or another machine.
license: MIT
metadata:
  author: Aegonex
  version: "0.3.0"
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

## Language

Every reply is in the user's language: labels, content, the question and its
options (`go` stays `go`). That is the language of the user's message; when
they typed only the skill's name, the language of the conversation so far;
else the language of `HANDOFF.md`; else English. This skill gives labels in
English and Thai; for another language, translate the English. The content
of `HANDOFF.md` follows the same language; its headings stay as in the
template, because `aegonex-init` reads them.

## Procedure

Run the steps in order and without commentary: the brief is the whole reply.

### 1. Git facts

```bash
git rev-parse --show-toplevel
git branch --show-current
git rev-parse --short HEAD
git status --short
git log --oneline -5
git diff --stat
git diff <file>        # once per file in git status; git output, not a file read
date +%F               # today: the HANDOFF date, new decisions, the commit message
```

Today's date comes from `date +%F`, never from a commit, a file or an
example in this skill.

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

If the file does not exist, skip this step; the brief's `Current work` row
says so.

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
lines; anything else in the diff goes in the brief's `Not recorded` row.

### 8. The brief

Print it as markdown, not inside a code block, so the table renders:

```
**Handoff saved.** Next session: start with `aegonex-init`

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**Will commit:** <files> with message `<message>`
```

The title names what happened and the next entry:

```
**Handoff saved.** Next session: start with `aegonex-init`
**บันทึก handoff แล้ว** ครั้งหน้าเปิดด้วย `aegonex-init`
```

On a project's first exit the first words are `Handoff created.` /
`สร้าง handoff แล้ว`, and when the project had no state files the title adds
that `aegonex-init` will set up the rest. When the user mentioned context,
compaction or a new session, the next entry is the command to type:
`Then type /compact and run aegonex-init` / `จากนั้นพิมพ์ /compact แล้วเรียก
aegonex-init` (commands in backticks when printed).

Rows, in this order. A row appears only when it has something to say: no
row reads "none", "0" or "-".

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| Stopped at / หยุดไว้ที่ | the work in flight in a few words; `not re-run` / `ยังไม่ได้รันเทสต์ใหม่` when a test was not re-run after an edit | always |
| Next step / ครั้งหน้าเริ่มที่ | HANDOFF's Next step | always |
| Current work / งานปัจจุบัน | `<M> <name>: <done> of <total> steps done`, plus `, <n> ticked today` when n > 0 / `<M> <name>: เสร็จ <done> จาก <total> ขั้น (วันนี้ติ๊กเพิ่ม <n>)`; without a roadmap `no ROADMAP.md yet: aegonex-plan creates it` / `ยังไม่มี ROADMAP.md: aegonex-plan จะสร้างให้` | always |
| Decided today / ตัดสินใจวันนี้ | each decision in a few words, separated by `;` | decisions were added |
| Dead ends / ทางตัน | each new dead end in a few words | dead ends were added |
| TODO in code / TODO ในโค้ด | `removed <n>; added at <file:line>` | anchors changed |
| Not recorded / ยังไม่ได้บันทึก | paths in `git status` still missing from HANDOFF, or files this skill touched outside its list | step 7 found any |

The header row is `| Item | Detail |` / `| เรื่อง | รายละเอียด |`. Paths,
commands and commit ids go in backticks. No emoji or icons. Not shown: the
HEAD sha, anchor counts that did not change, the raw git command.

The action line names the exact files to commit (`HANDOFF.md`,
`ROADMAP.md`, files with anchor edits, and the user's in-flight files only
if they said the work is ready) and a message under 72 characters.
Nothing is committed before the answer:

```
**Will commit:** `HANDOFF.md`, `ROADMAP.md` with message `docs: handoff <today>`
**จะ commit:** `HANDOFF.md`, `ROADMAP.md` ด้วยข้อความ `docs: handoff <today>`
```

The question comes last, once, and nothing follows it:
- If your harness has a tool that asks the user a multiple-choice question
  (Claude Code: `AskUserQuestion`), print the brief, then ask with it:
  `Commit now?` / `commit เลยไหม?`, options `go` (commit these files) and
  `Don't commit` / `ไม่ต้อง commit` (the files stay on disk).
- Otherwise the reply ends with this line, alone, after a blank line:
  `Reply **go** to commit, or say no to leave it uncommitted.` /
  `พิมพ์ **go** เพื่อ commit หรือบอกว่าไม่ต้อง`

If the user's message itself asked for the commit ("commit ด้วย", "commit
it"), that is the authorisation: commit after step 7, the action line
becomes `**Committed:** <sha> <files>` / `**commit แล้ว:** <sha> <files>`,
and there is no question.

After the answer: any clear yes is go (go, ok, yes, ได้, โอเค, ลุย); run
`git add <files> && git commit -m "<message>"` and reply in one line with the
sha, repeating the `/compact` command when it applies. On no, one line: the
files are saved on disk and not committed.

## Never commit on your own

The files are on disk the moment they are written; nothing is lost by not
committing. Whether and what to commit is the user's decision, asked in the
closing question. Agents without this skill committed anyway; their reasons:

| Excuse | Reality |
|---|---|
| "A WIP commit keeps the day's work safe" | The work is already on disk. A WIP commit puts unfinished code into history the user did not choose. |
| "Committing only HANDOFF.md and ROADMAP.md is harmless" | It is still a commit the user did not ask for, and it hides the question. |
| "The user said close the work, that includes saving" | Closing = writing the files. Saving to history = the user's word, in answer to the closing question. |
| "The user always says yes anyway" | Then the answer costs one word, or one click. |

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
| normal end of session | steps 1–8, the question asks about the commit |
| "context is heavy" mid-task | same; next step = continue the current work; the title gives the `/compact` command |
| user asked for the commit in the same message | steps 1–8, commit after step 7, `Committed <sha>`, no question |
| `## Session log` present | its lines become Decisions, Dead ends, Notes; the rewrite drops the section |
| never initialised (no state files) | HANDOFF.md created from template, no ROADMAP, the title points to `aegonex-init` |
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
| Ending with a summary instead of the brief | title, table, action line, question |
| A row that says none, 0 or nothing new | leave the row out |
| Showing the raw `git add … && git commit …` command | the files and the message; the command runs after go |
| Text after the question | the question is last |
