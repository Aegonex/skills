---
name: aegonex-done
description: Use when the user says a milestone or the whole plan is finished and wants it closed — "เสร็จแล้ว", "ปิด milestone", "งานนี้จบ", "done", "close M2", "ship it", "finished" — or when every step of the current milestone in ROADMAP.md is ticked. Also use when the user asks to clean up documents a finished piece of work no longer needs.
license: MIT
metadata:
  author: Aegonex
  version: "0.3.0"
---

# aegonex-done

## Overview

`aegonex-exit` closes a session; this skill closes a unit of work. The
unit is the milestone that `aegonex-plan` wrote. When the last milestone
closes, the project closes through the same skill.

Core principle: **closed means proved, then retired.** Every `done when`
of the milestone is checked now; only then is the milestone collapsed in
`ROADMAP.md` and its documents proposed for deletion. The skill deletes
nothing itself: every deletion is part of the commit command it proposes,
so the user sees the complete list before one `go`.

This is the one verb that may run checks, because proving completion is
its job. The user's word that the work is done is not evidence for a check
that can run.

## When to use

- The user says the milestone or the project is finished.
- Every step of the current milestone is ticked and the user wants it
  closed.

Not for: ending a session (`aegonex-exit`), planning the next milestone
(`aegonex-plan`), or ticking a single step (`aegonex-exit` does that from
evidence).

## Language

Every reply is in the user's language: labels, content, the question and its
options (`go` stays `go`). That is the language of the user's message; when
they typed only the skill's name, the language of the conversation so far;
else the language of `ROADMAP.md`; else English. This skill gives labels in
English and Thai; for another language, translate the English. Command
output is quoted as it is.

## Procedure

The steps run in order and without commentary: the brief is the whole
reply. The first failing step ends the skill at step 5 with the brief for a
milestone that cannot close.

### 1. Git facts and the milestone

```bash
git rev-parse --show-toplevel
git branch --show-current
git rev-parse --short HEAD
git status --short
git log --oneline -5
date +%F                  # today, for `closed <date>`
```

Read `ROADMAP.md`. The milestone being closed is the one the user named,
else the first unticked `- [ ] M…` line. Collect its `done when` and every
step's `done when`, its `docs:` line, and the `Scratch:` line of
`AGENTS.md` (a line starting with `Scratch:`).

### 2. Prove it

For each `done when`, in order:
- a command or a test: run it now, keep the output, pass or fail by its
  exit code and what it printed;
- a visible behaviour: ask the user for one word, or accept it if the user
  already stated it in this session.

Then the anchor grep:

```bash
grep -rn --exclude-dir={node_modules,.git,dist,build,vendor,target} --exclude={AGENTS.md,CLAUDE.md,ROADMAP.md,HANDOFF.md} -E "AIDEV-(TODO|NOTE)" .
```

Any `AIDEV-TODO` that names this milestone is a failing check.

If anything failed: the brief lists it, its first step is the fix, and
steps 3 and 4 do not happen. The user insisting does not
change the outcome; the failing command's output is the answer.

### 3. Retire

In `ROADMAP.md`, the closed milestone collapses to one line:
`- [x] M<n> — <name> · closed <date> · <last commit sha>`. Its steps and
its `docs:` line are removed; git history keeps them. Under Decisions,
lines that only served this milestone are removed and lines that still
constrain later work are kept. Under `Not doing`, entries that lost their
meaning are removed. Nothing under a later milestone changes. `AIDEV-NOTE`
comments are never touched. `HANDOFF.md` is not touched: exit owns it and
will write `M<n> closed, next: aegonex-plan`.

### 4. Retrospective

From the milestone's dead ends (`HANDOFF.md`, the session), pick the one
that would have saved the most time had it been a rule. Write it as one
line under Rules in `AGENTS.md`; the brief shows it in the `New rule` row.
When no dead end generalises there is no rule and no row. This is the only write any skill makes to
`AGENTS.md` after scaffolding; it goes into the same commit, and the user
strikes it with the go if they disagree.

### 5. The brief

Candidates for deletion are exactly: the paths on the closed milestone's
`docs:` line, and files under the `Scratch:` directory. Nothing else is
ever a candidate. On project close (no milestone left), `HANDOFF.md` is also
a candidate: there is no session to hand off to. Tracked files are deleted
with `git rm`, untracked ones with `rm` (git cannot restore those, so the
brief lists them by name, apart from the others).

Print the brief as markdown, not inside a code block, so the table renders.
When every check passed:

```
**<M> <name> can close.** All <n> checks passed

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**Will commit:** the deletions above, `ROADMAP.md` and `AGENTS.md`, with message `chore: close <M>`
```

Thai title: `**ปิด <M> <name> ได้** เช็กผ่านครบ <n>/<n>`; header
`| เรื่อง | รายละเอียด |`; action line `**จะ commit:** การลบข้างบน พร้อม
ROADMAP.md และ AGENTS.md ด้วยข้อความ chore: close <M>` (paths and the message
in backticks). Rows, in this order, only when they have something to say:

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| ROADMAP / ROADMAP | `<M> collapsed to one line` / `ยุบ <M> เหลือบรรทัดเดียว`, plus the decisions and Not doing lines dropped, if any | always |
| New rule in AGENTS.md / กฎใหม่ใน AGENTS.md | the retro rule | step 4 wrote one |
| Delete, restorable from git / ลบ (กู้คืนจาก git ได้) | the tracked candidates | there are any |
| Delete, not in git, cannot be restored / ลบ (ไม่อยู่ใน git กู้คืนไม่ได้) | the untracked candidates | there are any |
| Next / ต่อไป | `aegonex-plan for <next M>; type /clear first` / `aegonex-plan วางแผน <next M> แนะนำพิมพ์ /clear ก่อน`; on project close `project closed; end with aegonex-exit` / `ปิดโปรเจกต์แล้ว จบด้วย aegonex-exit` | always |

With no candidates the delete rows are left out and the action line commits
`ROADMAP.md` and `AGENTS.md` only.

When a check failed:

```
**<M> <name> cannot close yet.** <passed> of <total> checks passed

| Check | Result |
|---|---|
| <the command in backticks, or the behaviour in words> | <failed: the reason from its output, in a few words> |

**First step:** <the fix>
```

Thai: `**ยังปิด <M> ไม่ได้** เช็กผ่าน <passed>/<total>`, header
`| เช็ก | ผล |`, `ผ่าน` / `ไม่ผ่าน: <reason>`, `**ขั้นแรก:**`. One row per
check, failing ones first; an open `AIDEV-TODO` of this milestone is a
failing row `TODO <file:line>`. Nothing else is written, and nothing is
deleted.

Paths, commands and commit ids go in backticks. No emoji or icons. Not
shown: the HEAD sha, counts of collapsed steps or NOTEs, the raw git command.

The question comes last, once, and nothing follows it:
- If your harness has a tool that asks the user a multiple-choice question
  (Claude Code: `AskUserQuestion`), print the brief, then ask with it. All
  passed: `Delete and commit now?` / `ลบและ commit เลยไหม?` (`Commit now?` /
  `commit เลยไหม?` when nothing is deleted), options `go` and `Not yet` /
  `ยังไม่ปิด`. A check failed: `Start the fix?` / `เริ่มแก้เลยไหม?`, options
  `go` and `Not now` / `ไม่ใช่ตอนนี้`.
- Otherwise the reply ends with one line, alone, after a blank line. All
  passed: `Reply **go** to delete and commit, or tell me which files to
  keep.` / `พิมพ์ **go** เพื่อลบและ commit หรือบอกว่าอยากเก็บไฟล์ไหนไว้`. A
  check failed: `Reply **go** to start the fix, or tell me what to do
  instead.` / `พิมพ์ **go** เพื่อเริ่มแก้ หรือบอกว่าอยากทำอะไรแทน`.

Nothing is deleted or committed before the answer. Any clear yes is go (go,
ok, yes, ได้, โอเค, ลุย). After a pass, go runs
`git rm <tracked> && rm <untracked> && git add ROADMAP.md AGENTS.md && git commit -m "chore: close <M>"`
and the reply is one line: the sha, then the `Next` row again.

## Never close on a word

| Excuse | Reality |
|---|---|
| "The user said it is done, ticking is a formality" | The user's word covers behaviours they saw, not commands that can run. Run them. |
| "The failing check is flaky, the code is fine" | A flaky check is a failing check. It goes under what is missing. |
| "I'll delete the scratch files now, they are junk anyway" | Nothing is deleted outside the approved commit command. |
| "I'll also clean up docs/ while I'm here" | Only the `docs:` line and `Scratch:`. Everything else has an owner. |
| "I'll run exit as well, to be complete" | Exit is the user's next word, named on the last line. |
| "The decision is old, nobody needs it" | A decision that still constrains later work stays. |

## Red flags — stop, you are leaving the procedure

- `rm`, `git rm` or `git commit` run before the user answered go.
- A `[x]` written before the check ran.
- `HANDOFF.md` opened for writing.
- A path in a delete row that is on neither the `docs:` line nor under
  `Scratch:`.
- "Let me just tick it, the tests passed yesterday."

## Quick reference

| Situation | Done does |
|---|---|
| All checks pass, docs listed, scratch files present | collapse, retro, both delete rows, one question |
| One check fails | the checks table, no collapse, no deletion, the first step is the fix |
| User insists after a failed check | same brief; the command output is the answer |
| No `docs:` line, no `Scratch:` | no delete rows; the commit is `ROADMAP.md` and `AGENTS.md` |
| Last milestone | `HANDOFF.md` joins the candidates; the `Next` row names `aegonex-exit` |
| Milestone has an open `AIDEV-TODO` | cannot close; the first step is that TODO |
| A row with nothing to say | left out |
