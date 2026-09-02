---
name: aegonex-done
description: Use when the user says a milestone or the whole plan is finished and wants it closed — "เสร็จแล้ว", "ปิด milestone", "งานนี้จบ", "done", "close M2", "ship it", "finished" — or when every step of the current milestone in ROADMAP.md is ticked. Also use when the user asks to clean up documents a finished piece of work no longer needs.
license: MIT
metadata:
  author: Aegonex
  version: "0.2.0"
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

## Procedure

The steps run in order. The first failing step ends the skill at step 5
with a `not done` brief.

### 1. Git facts and the milestone

```bash
git rev-parse --show-toplevel
git branch --show-current
git rev-parse --short HEAD
git status --short
git log --oneline -5
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

If anything failed: the brief's `Checks:` line names it, `First step:` is
to fix it, and steps 3 and 4 do not happen. The user insisting does not
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
line under Rules in `AGENTS.md` and show it in the `Retro:` line; `none`
when no dead end generalises. This is the only write any skill makes to
`AGENTS.md` after scaffolding; it goes into the same commit, and the user
strikes it with the go if they disagree.

### 5. The brief

Candidates for deletion are exactly: the paths on the closed milestone's
`docs:` line, and files under the `Scratch:` directory. Nothing else is
ever a candidate; without both, `Cleanup:` reads `none declared`. On
project close (no milestone left), `HANDOFF.md` is also a candidate: there
is no session to hand off to. Tracked files go in `git rm`, untracked ones
in `rm` (git cannot restore those, so they are always listed by name).

Print exactly this shape, then stop.

```
Repo: <project> · <branch> · HEAD <sha>
Checks: <passed>/<total> done when passed · <failed checks> | milestone not done: <what is missing>
ROADMAP: <milestone> closed (<date>) · <n> steps collapsed · decisions kept <n>, dropped <n>
Anchors: <n> TODO for this milestone (must be 0) · <n> NOTE kept
Cleanup: <paths, tracked | untracked> | none declared
Retro: <rule added to AGENTS.md> | none
Commit? `git rm <tracked> && rm <untracked> && git add ROADMAP.md AGENTS.md && git commit -m "chore: close <milestone>"` — go?
```

When a check failed, the brief is three lines: `Repo:`, `Checks:` with
what is missing, and `First step: <fix> — go?`.

Each line starts with its label in plain text; no emoji or symbol precedes
a label. The command is not run. The closing line names the next verb in
the user's language, once: `next: aegonex-plan` while milestones remain,
`project closed; end with aegonex-exit` when none do, then on its own
line the harness command `/clear` (the finished milestone's context is
dead weight; init rebuilds the picture from the files).

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

- `rm`, `git rm` or `git commit` run before the user answered `go?`.
- A `[x]` written before the check ran.
- `HANDOFF.md` opened for writing.
- A path in `Cleanup:` that is on neither the `docs:` line nor under
  `Scratch:`.
- "Let me just tick it, the tests passed yesterday."

## Quick reference

| Situation | Done does |
|---|---|
| All checks pass, docs listed, scratch files present | collapse, retro, one command with every deletion, `go?` |
| One check fails | three-line brief, no collapse, no deletion, `First step:` is the fix |
| User insists after a failed check | same brief; the command output is the answer |
| No `docs:` line, no `Scratch:` | `Cleanup: none declared` |
| Last milestone | `HANDOFF.md` joins the candidates; closer is `aegonex-exit` |
| Milestone has an open `AIDEV-TODO` | not done; `First step:` is that TODO |
