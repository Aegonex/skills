---
name: aegonex-exit
description: Use when a work session is ending or must be handed off — "ปิดงาน", "พอแค่นี้", "จบวันนี้", "wrap up", "done for today", "handoff" — or when the context is getting heavy and the user wants to compact or open a new session. Also use before switching to another AI agent, or when the user asks to push or merge what they have before it is finished ("push what I have", "merge ที่ทำไว้ก่อน").
license: MIT
metadata:
  author: Aegonex
  version: "0.5.0"
---

# aegonex-exit

## Overview

Every session closes through this skill. Before its question it writes what `aegonex-init` reads
next time, in the state folder (step 1), never the main folder: `ROADMAP.md` reconciled,
`HANDOFF.md` rewritten (or created, on a project's first exit), plus anchor comments tidied in each
folder the session touched (step 4). Nothing else is written or moved before the go, and the go
only commits (push what I have: it also syncs, scans and lands). It is the only owner of
`HANDOFF.md`; `aegonex-note` may add lines to its `## Session log`; this skill folds them in.

Core principle: **everything written comes from evidence the session produced** — a commit id, a
test that ran here and passed, a diff, a session-log line, or the user's own words. Nothing is
ticked, claimed or asserted from memory of what "should" have happened. It never commits on its own
and never writes any part of a secret; agents without this skill did both, so each has a section below.

## When to use

- The user ends the session: "ปิดงาน", "พอแค่นี้", "wrap up", "done for today".
- The context is heavy and a compaction or a new session is coming.
- The work moves to another agent or machine.

Not for: starting a session (`aegonex-init`), recording one fact mid-task
(`aegonex-note`), or closing a milestone (`aegonex-done`).

## Language

Every reply is in the user's language: labels, content, the question and its options (`go` stays
`go`). That is the language of the user's message; a message with no language of its own (only the
skill's name, or a bare answer such as `go`, `ok`, `yes`) takes the conversation's so far, else
`HANDOFF.md`'s, else English. Every line this skill writes is in that language too, whatever
language the file or the template already uses: `HANDOFF.md` (step 5, carried lines translated) and
the new `ROADMAP.md` lines of step 3 (Decisions, new steps); a number or name replaced inside an
existing line leaves the rest of that line as it was. Headings, the markers `Branch:`, `HEAD:`,
`done when:`, `docs:`, `(in progress)`, `after:` and `t-<slug> done when:` (other skills read them), paths,
commands, branch names and commit ids stay as they are. Labels here are English and Thai; for
another language, translate the English.

## Procedure

Run the steps in order and without commentary: the brief is the whole reply. Every command, reads
included, is its own tool call on one line: no `&&`, `||` or `;`; an exit code is read from the
tool result (no error shown = 0), never with `; echo $?` or `|| true`. Git is always
`git -C "<folder>"` with an absolute path, even when the shell already stands in that folder or a
harness prefix cd's there; never `cd` to run a read.

### 1. Git facts

`<here>` is the folder the session opened in (removed since: the shell's folder); `not a git repository` there: read `../aegonex-init/references/repos.md` and follow it.
`git -C "<here>" worktree list --porcelain`: `<main>` is its first `worktree` path; a unit
folder is one with a `branch refs/heads/aegonex/…` line. The state folder is the `aegonex/m<n>`
folder that is not closed (`git -C "<f>" log -1 --first-parent --no-merges --format=%s` is not
`chore: close m<n>`); else the unit folder the session worked in. With no unit folder at all, the
whole reply is `No work folder is open; nothing to hand off. Start with aegonex-init.` /
`ยังไม่มีโฟลเดอร์งาน ไม่มีอะไรต้องส่งต่อ เริ่มด้วย aegonex-init`. Then, once per folder the session
touched (`<f>`):

```bash
git -C "<f>" branch --show-current
git -C "<f>" rev-parse --short HEAD
git -C "<f>" -c core.quotePath=false status --short
git -C "<f>" log --oneline -5
git -C "<f>" diff --stat
git -C "<f>" diff -- <file>   # once per file in the status (git output, not a file read)
date +%F                      # today: the HANDOFF date, new decisions, the commit message
```

Today's date comes from `date +%F` (PowerShell: `Get-Date -Format yyyy-MM-dd`), never from a
commit, a file or an example in this skill. Reads: `HANDOFF.md`, `ROADMAP.md`, `<main>/AGENTS.md`
for its Working mode and Leader mode sections (never the unit's copy: a unit branch made before
setup lacks them), `assets/HANDOFF.md` (the file beside this SKILL.md, read by that path) and git
output. File names come from the `status --short` and `worktree list` output above; `ls` (but the one
`repos.md` names) and `find` are never run, on the project or on the skill folder. Code is seen through the diff above, untracked
files by name only; no source file, document, manifest or README is opened, except a file whose
anchor line step 4 edits.

### 2. Session facts

Start with the old `HANDOFF.md` in the state folder. Its `## Session log` lines are facts already
recorded (decision, dead end, environment fact). Its Dead ends and Notes lines are carried (step 5)
unless this session disproved or replaced one; while a task is the state folder and a closed `m<n>`
folder waits for its pull request, that folder's `HANDOFF.md` Dead ends and Notes lines are carried
too, once each. Then, from the session, list:
- work completed, each with its evidence: a commit id, a test that ran here and its result, or the user's words
- work in flight: which files, what is missing before it is done
- decisions the user made (what; why only when the user or the session gave a reason)
- dead ends: what was tried, why it failed, so nobody retries it
- environment facts: commands that need flags or variables, things not in git
- working documents: new files under `docs/` that the user or a Session log line called working, draft or temporary

A fact about the environment is recorded as the session showed it. No
probe is run now to "verify" it, and no check is claimed that did not run.

### 3. Reconcile ROADMAP.md

Skip this step when `ROADMAP.md` does not exist (the `Current work` row says so) or the state folder
is a task, which never touches `ROADMAP.md` (its decisions become Notes, step 5).

| Situation | Do |
|---|---|
| step whose `done when` was met this session: a command or test it names ran here and passed (a commit alone is not enough); a file or decision it names: the commit that made it; a behaviour: seen here, or the user said so | tick it `[x]` |
| step with uncommitted or partial code | leave `[ ]`; make sure ` (in progress)` is at the end of the line exactly once |
| decision made today (from the log or the session) | add under Decisions: `YYYY-MM-DD — <decision> (<why>)`, the `(<why>)` as step 5 says |
| a milestone or step line whose number or name (in its title or its `done when`) a decision made today changed | replace only that number or name; the Decisions line keeps the form above: `ROADMAP updated` is a note in the brief's `Decided today` row (step 8), never written in `ROADMAP.md` |
| new step discovered | add under its milestone as `- [ ] <step> · done when: <command, test or behaviour>` |
| working document from step 2 | add its path to the milestone's `docs:` line (create the line if missing); other new documents are never listed there |

Never tick a milestone line, even when all its steps are ticked: only `aegonex-done` closes a
milestone. Change nothing else. The file stays under two pages.

### 4. Anchors

```bash
git -C "<f>" grep -n --untracked -E "AIDEV-(TODO|NOTE)" -- . ":(exclude,glob)**/AGENTS.md" ":(exclude,glob)**/CLAUDE.md" ":(exclude,glob)**/ROADMAP.md" ":(exclude,glob)**/HANDOFF.md"
```

- `AIDEV-TODO` whose work finished this session (evidence as above): delete it.
- Work stopped mid-way in a file with no `AIDEV-TODO` naming this unit: add one line
  `AIDEV-TODO(<unit>): <what is missing>` there, `<unit>` being `M<n>` or `t-<slug>`. One that names
  the unit in its text (`(ROADMAP M2)`) gets no second, tagged line; a plain `TODO` comment stays as it is.
- An anchor whose text a decision made wrong (a number, a name): update it.

Only comment lines change; no other line of code is touched by this skill. An anchor edit in a file
with other uncommitted work stays on disk with that work and is not committed now.

### 5. Rewrite HANDOFF.md

Overwrite the whole file in the state folder from `assets/HANDOFF.md`, in the reply's language
(Language), or create it from the template when it does not exist. Never append to the old one:
only its Dead ends and Notes lines are carried; the rest is superseded, and the commit history
keeps it. The rewrite has no `## Session log`: its lines went into the sections below in step 2.

Required slots:
- `# HANDOFF — <YYYY-MM-DD>`
- `Branch: <branch> · HEAD: <short sha>` of the state folder, at writing time
  (`git -C "<state folder>" branch --show-current`, `git -C "<state folder>" rev-parse --short HEAD`;
  `aegonex-init` ignores the handoff commit)
- **Stopped at**: one line per file `status --short` lists but `HANDOFF.md` and `ROADMAP.md` (step 7):
  what changed (an untracked file: only what the session said about it); a file not in the action
  line adds `not committed, not part of the handoff commit` / `ยังไม่ commit (ไม่รวมใน commit handoff)`;
  with push what I have (step 9), one in the action line adds `committed unfinished, landed on <Base>` /
  `commit แล้ว (ยังไม่เสร็จ) push เข้า <Base> แล้ว`, written as done: never as staged or with will / จะ. Then
  the state of the work in flight; a test not re-run after an edit says `not re-run` / `ยังไม่ได้รันเทสต์ใหม่`
- **Next step**: one action (never two joined by `then` / `แล้ว`), the first thing the next session
  does, tagged with its unit: `(M<n>)` or `(t-<slug>)`
- **Dead ends** and **Notes for the next session**: the old lines this session did not disprove or
  replace, in their order, then today's; an open task's `t-<slug> done when:` and `t-<slug> after:` lines
  are Notes. A task as the state folder writes each decision made today as a Note `YYYY-MM-DD — <decision> (<why>)`,
  and while a closed `m<n>` waits for its pull request the last Note is `M<n> closed, waits for its pull request (aegonex/m<n>)`
  / `M<n> ปิดแล้ว รอ merge pull request (aegonex/m<n>)`, never twice: a carried copy moves last, and none
  is kept once `m<n>` no longer waits. Past 60 lines, drop carried lines from the top of Dead ends, then of Notes, never a `t-<slug> after:` line.
- **Suggested skills**: `aegonex-init` first, then what the next step needs (`aegonex-done` when it
  lands a task or closes a milestone)

Limits: 60 lines. Paths and commit ids, not pasted code or commit messages. A decision's `(<why>)`,
here and in step 3, is written only when the user or the session gave a reason; with none the line
ends after the decision, never with a placeholder or an invented reason.

### 6. Secret scan

Before saving any file, read the text about to be written and look for credentials: values after
`KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `Bearer`, prefixes like `sk-`, `ghp_`, `xox`, `AKIA`, `.env`
values, and any random string longer than 16 characters. Each one becomes `<redacted>` or a
description such as `<the prod JWT secret>`; the fact around it stays ("the shell exports the prod
JWT secret by mistake; run tests with `JWT_SECRET=dev`"). After saving, run exactly:

```bash
git -C "<f>" grep -n -i -E --untracked 'KEY|TOKEN|SECRET|PASSWORD|Bearer|sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' -- HANDOFF.md ROADMAP.md
```

and read every hit (exit 1 with no output: no hits): a variable name is fine, a value is not, unless
it is an obvious placeholder (`dev`, `test`, `example`, `changeme`). A prefix, a suffix, a "first
few characters" of a secret is a secret.

### 7. Verify against git

Read the status again. Every path it lists, other than `HANDOFF.md` and `ROADMAP.md` (this skill's
own files, named in the action line), appears in Stopped at; if one is missing, add it. Read
`HANDOFF.md` back (a file read, not `wc`): at most 60 lines. The only files changed by this skill are
`HANDOFF.md`, `ROADMAP.md` and anchor comment lines; anything else in the diff goes in `Not recorded`.

### 8. The brief

Print it as markdown, not inside a code block, so the table renders:

```
**Handoff saved.** Next session: start with `aegonex-init`

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**Will commit:** <files> with message `<message>`
```

Thai title: `**บันทึก handoff แล้ว** ครั้งหน้าเปิดด้วย aegonex-init`. When `HANDOFF.md` did not exist, the
first words are `Handoff created.` / `สร้าง handoff แล้ว`. When the user mentioned context, compaction
or a new session, the next entry is the command to type: `Then type /compact and run aegonex-init` /
`จากนั้นพิมพ์ /compact แล้วเรียก aegonex-init` (commands in backticks when printed).

Rows in this order; a row with nothing to say ("none", "0", "-") is left out.

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| Stopped at / หยุดไว้ที่ | the work in flight in a few words; `not re-run` / `ยังไม่ได้รันเทสต์ใหม่` when a test was not re-run after an edit | always |
| Next step / ครั้งหน้าเริ่มที่ | HANDOFF's Next step | always |
| Current work / งานปัจจุบัน | `<M> <name>: <done> of <total> steps done`, plus `, <n> ticked today` when n > 0 / `<M> <name>: เสร็จ <done> จาก <total> ขั้น (วันนี้ติ๊กเพิ่ม <n>)`, counted only from the open milestone folder's `ROADMAP.md`, never a task's or `<main>`'s copy; a task as the state folder: `t-<slug>: <the task in a few words>`, then `; M<n> closed, waits for its pull request` / `; M<n> ปิดแล้ว รอ merge pull request` when one waits, or `; no ROADMAP.md yet: aegonex-plan creates it` / `; ยังไม่มี ROADMAP.md: aegonex-plan จะสร้างให้` when no folder has a `ROADMAP.md` | always |
| Decided today / ตัดสินใจวันนี้ | each decision in a few words, separated by `;`; one that changed a number or name in a milestone or step line ends with `ROADMAP updated` / `แก้ ROADMAP แล้ว` (step 3) | decisions were added |
| Dead ends / ทางตัน | each new dead end in a few words | dead ends were added |
| TODO in code / TODO ในโค้ด | `removed <n>; added at <file:line>` | anchors changed |
| Not recorded / ยังไม่ได้บันทึก | paths the status lists still missing from HANDOFF, or files this skill touched outside its list | step 7 found any |

The header row is `| Item | Detail |` / `| เรื่อง | รายละเอียด |`. Paths, commands and commit ids go
in backticks. No emoji or icons. Not shown: the HEAD sha, anchor counts that did not change, the raw
git command.

The action line names the exact files to commit (`HANDOFF.md`, `ROADMAP.md`, files whose only change
is an anchor edit, and the user's in-flight files only if they said the work is ready), each
committed in the folder that holds it, and a message under 72 characters. Nothing is committed
before the answer:

```
**Will commit:** `HANDOFF.md`, `ROADMAP.md` with message `docs: handoff <today>`
**จะ commit:** `HANDOFF.md`, `ROADMAP.md` ด้วยข้อความ `docs: handoff <today>`
```

The question comes last, once, and nothing follows it:
- If your harness has a tool that asks the user a multiple-choice question (Claude Code:
  `AskUserQuestion`), print the brief, then ask with it: `Commit now?` / `commit เลยไหม?`, options
  `go` (commit these files) and `Don't commit` / `ไม่ต้อง commit` (the files stay on disk).
- Otherwise the reply ends with this line, alone, after a blank line:
  `Reply **go** to commit, or say no to leave it uncommitted.` /
  `พิมพ์ **go** เพื่อ commit หรือบอกว่าไม่ต้อง`

If the user's message itself asked for the commit ("commit ด้วย", "commit it"), that is the
authorisation: commit after step 7, the action line becomes `**Committed:** <sha> <files>` /
`**commit แล้ว:** <sha> <files>`, and there is no question.

After the answer: any clear yes is go (go, ok, yes, ได้, โอเค, ลุย); run these two, each its own call,
`<f>` being the absolute path of the folder that holds the files: `git -C "<f>" add -- <files>` and
`git -C "<f>" commit -m "<message>" -- <files>`. Reply in one line with the sha, repeating the
`/compact` command when it applies; a task whose last part is integrated then gets, on its own last
line, the land question of the Go rule in `<main>/AGENTS.md`. On no, one line: saved on disk, not committed.

### 9. Land unfinished work

Only when the user asks to push or merge what they have. `<u>` is the unit they named, else the unit
folder `<f>` the session worked in; its in-flight files are in the action line (Stopped at: step 5).
A unit with an `after:` record (its ROADMAP line, or a `t-<slug> after:` line) is pushed only once the landed check of
`../aegonex-init/references/repos.md`, run before step 5, passes; until then the question stays step 8's and the action line and Stopped at read `committed, not pushed: lands after <r> <v>` / `commit แล้ว ยังไม่ push: รอ <r> <v>`.
The action line becomes `**Will commit:** <files> with message <message>, then bring in <Base> (Sync), scan for keys and push aegonex/<u> to <Base> (unfinished)`
/ `**จะ commit:** ... แล้วดึง <Base> มารวม (Sync) ตรวจหา key และ push aegonex/<u> เข้า <Base> (ยังไม่เสร็จ)`;
the question `Commit and push now?` / `commit และ push เลยไหม?`, options `Don't push` / `ไม่ต้อง push`
first, then `go`. Without the question tool the reply ends, alone after a blank line, with:
Reply **go** to commit and push, or say no to leave it unpushed. /
พิมพ์ **go** เพื่อ commit และ push หรือบอกว่าไม่ต้อง push

This go lands but keeps the folder (unlike the `Working mode` land go, removal is asked in 5); it
runs, in order, each failure stopping it with the reason (`aegonex-done` is `../aegonex-done/SKILL.md`):
1. the commit, as in step 8;
2. **Sync** as `aegonex-done` step 2 says; nothing lands after a failed merge;
3. the secret scan of `aegonex-done` step 6; a hit: `a key is in <file>; nothing was pushed`;
4. **Land** as the `Working mode` section of `<main>/AGENTS.md` says, the push output read as `aegonex-done`
   step 7.3 reads it, except that `[rejected]` stops with `Base moved: run aegonex-exit again` /
   `Base ขยับแล้ว: เรียก aegonex-exit อีกครั้ง`. A pull request, as step 7.3 of `../aegonex-done/references/pull-request.md`
   says: the folder is kept, nothing is asked, the reply gives the link or that step's `open a pull request ... on your host` line;
5. landed: a reply of at most 4 lines, no title or table, printed as plain text with only the sha,
   paths and branch names in backticks. `<sha>` is the tip that landed: `git -C "<f>" rev-parse --short HEAD`
   after the push (the Sync merge when Sync made one, not the handoff commit):
   `<sha>` handoff committed · `aegonex/<u>` landed on `<Base>` (unfinished) /
   `<sha>` commit handoff แล้ว · `aegonex/<u>` push เข้า `<Base>` แล้ว (ยังไม่เสร็จ)
   then the remove line, asked once, `.env` standing for the ignored files that go with the folder
   (`aegonex-done` step 6; with no such files, leave out the parentheses). With the question tool:
   `Remove .worktrees/<u> (with .env) now?` / `ลบ .worktrees/<u> (พร้อม .env) เลยไหม?`, options `Keep` /
   `เก็บไว้` first and `Remove` / `ลบ`. Otherwise the reply ends with:
   Reply **remove** to remove `.worktrees/<u>` (with `.env`), or anything else to keep it. /
   พิมพ์ **remove** เพื่อลบ `.worktrees/<u>` (พร้อม `.env`) หรือพิมพ์อย่างอื่นเพื่อเก็บไว้
   No answer is Keep. Remove runs **Clean up** as `aegonex-done` step 7.4 says; a milestone removed
   unfinished is reopened from Base by the next `aegonex-init`.

## Never commit on your own

The files are on disk once written; nothing is lost by not committing. Whether and what to commit is
the user's decision, asked in the closing question. Agents without this skill committed anyway:

| Excuse | Reality |
|---|---|
| "A WIP commit keeps the day's work safe" | The work is already on disk. A WIP commit puts unfinished code into history the user did not choose. |
| "Committing only HANDOFF.md and ROADMAP.md is harmless" | It is still a commit the user did not ask for, and it hides the question. |
| "The user said close the work, that includes saving" | Closing = writing the files. Saving to history = the user's word, in answer to the closing question. |
| "The user always says yes anyway" | Then the answer costs one word, or one click. |

## Never probe, never tick on hope

| Excuse | Reality |
|---|---|
| "I need a passing test to tick this" | A run now is a new task. Tick only what ran during the session; otherwise leave `[ ]` and write `not re-run` / `ยังไม่ได้รันเทสต์ใหม่` in Stopped at. |
| "I'll check the environment quickly to confirm the note" | Record what the session showed. Probing now installs things and changes the tree. |
| "The code exists, so the step is done" | Evidence as step 3 names it: a run here for a command or test (a commit is not enough), the commit for a file or decision, seen here or the user's word for a behaviour. Existence is not evidence. |

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
- Writing HANDOFF.md in English because the old file was.
- `npm install`, `npx`, `pytest`, `cargo test` or any runner in a command.
- `ls` (but `repos.md`'s) or `find` (the skill folder too), `cat` or a file read of source, docs or README "for context".
- A `cd` before a read, `&&` `||` `;` in a command, or git without `-C "<absolute folder>"`.

## Quick reference

| Situation | Exit does |
|---|---|
| normal end of session | steps 1–8, the question asks about the commit |
| "context is heavy" mid-task | same; next step = continue the current work; the title gives the `/compact` command |
| user asked for the commit in the same message | steps 1–8, commit after step 7, `Committed <sha>`, no question |
| "push what I have" | steps 1–8, then step 9: commit, Sync, scan, push to Base, Remove / Keep (no answer keeps) |
| session worked in `t-fix` while `.worktrees/m2` is open, not closed | HANDOFF and ROADMAP change in `m2`; `t-fix` gets only anchor lines |
| session worked in `t-fix` while a closed `m2` waits for its pull request | HANDOFF in `t-fix`, today's decisions as Notes, the last Note `M2 closed, waits for its pull request (aegonex/m2)` |
| all steps of the milestone ticked | the milestone line stays `[ ]`; Next step: `run aegonex-done (M<n>)` / `เรียก aegonex-done (M<n>)` |
| an old dead end or note this session did not disprove | carried into the new HANDOFF |
| `## Session log` present | its lines become Decisions, Dead ends, Notes; the rewrite drops the section |
| no work folder open | one line: nothing to hand off, start with `aegonex-init` |

## Common mistakes

| Mistake | Instead |
|---|---|
| Ticking a step because the code exists | the evidence step 3 names for its `done when`; a commit alone never ticks a command or test |
| Running a test or an install to get evidence | record `not re-run` (step 5); the next session runs it |
| Appending today's notes under the old handoff | rewrite the file; carry only the old Dead ends and Notes lines still true |
| Ticking the milestone line | only `aegonex-done` closes a milestone |
| Pasting the diff or the commit message into HANDOFF | the path and the commit id |
