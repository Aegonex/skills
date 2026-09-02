---
name: aegonex-plan
description: Use when a project needs its next milestone planned — there is no ROADMAP.md, the current milestone is fully ticked, aegonex-init said "run aegonex-plan", or the user says "วางแผน", "เพิ่มฟีเจอร์", "plan", "roadmap", "new feature", "what next". Also use when a feature request arrives that is bigger than one step.
license: MIT
metadata:
  author: Aegonex
  version: "0.2.0"
---

# aegonex-plan

## Overview

This skill owns the structure of `ROADMAP.md`: the goal, the milestones,
their steps, what "done" looks like for each, what is deliberately not being
done, decisions and constraints. It asks a few questions, one at a time,
and stops asking the moment it can write one milestone whose every step
has a check. Then it writes the file and hands the user the first step.

Core principle: **a step without a `done when` is not a step.** The check
is what `aegonex-exit` ticks against and what `aegonex-done` runs. Every
step must be small enough to finish in one session, because `HANDOFF.md`
carries one next step at a time.

The artifact is `ROADMAP.md` and nothing else: no spec document, no
implementation plan, no code, no `HANDOFF.md`. An agent that has a deeper
design skill uses it on a step when the step starts, never on the roadmap.

## When to use

- `ROADMAP.md` does not exist.
- The current milestone has no unticked step left.
- The user asks to plan, add a feature, or asks what comes next.

Not for: opening a session (`aegonex-init`), recording a single decision
(`aegonex-note`), closing a milestone (`aegonex-done`), or designing the
inside of one step (the agent's own design tools, after the step starts).

## Procedure

### 1. Read the testimony

Read `ROADMAP.md` if it exists, `AGENTS.md`, `HANDOFF.md` if it exists, and
`git log --oneline -20`. Manifests (`package.json` and the like) may be
read for the stack. No source file is opened: the roadmap is built from
what the user wants, not from what the code does.

### 2. Ask, one question per message

Ask in the user's language. Prefer multiple choice. One question per
message, never a list. At most seven questions per milestone, counting
every question of any kind. Ask in this order, and skip any question whose
answer is already known from the files or from the user's first message:

1. Who is it for and what problem does it solve?
2. What does "done" look like, as something a person can see or a command
   can check?
3. What is deliberately not being done?
4. Constraints: deadline, platform, budget, rules that cannot move.
5. The largest unknown or risk.
6. The order of the steps.

Stop asking the moment the write condition holds, even if questions
remain. When the user answers "ไม่รู้" or "you decide", decide, record it
under Decisions with `(agent's call)`, and move on; do not ask again.

### 3. Write condition

All of these are true:
- one milestone has a `done when` of its own, observable by a person or a
  command;
- it has at most seven steps;
- every step has a `done when` naming a command, a test, or a visible
  behaviour;
- every step is small enough to finish in one session;
- `Not doing` has at least one line, or the user explicitly said nothing is
  out of scope.

### 4. Write ROADMAP.md

From `assets/ROADMAP.md`. Headings are fixed English, exactly as in the
template, so `aegonex-init`, `aegonex-exit` and `aegonex-done` can parse
them; the content is in the user's language.

| Situation | Do |
|---|---|
| No `ROADMAP.md` | write the whole file: Goal, the milestone (M1), later milestones as one line each with a `done when` if known, Not doing, Decisions, Constraints |
| `ROADMAP.md` exists | keep every ticked line, every existing Decisions line and every Constraints line byte for byte; restructure only unticked milestones and steps; never un-tick; add, never rewrite, decisions |
| A `docs:` line | keep it; add a path only for a document the user named |

Step shape: `- [ ] <step> · done when: <command, test or behaviour>`.
Milestone shape: `- [ ] M<n> — <name> · done when: <observable>`.

The file stays under two pages. Paths and commands, not prose about how.

### 5. The brief

Print exactly this shape, then stop.

```
Repo: <project> · <branch> · HEAD <sha>
ROADMAP written (<date>): <milestone> — <n> steps, each with done when · not doing: <n> · questions asked: <n>
Decisions: +<n> · Constraints: +<n>
First step: <step 1 of the milestone, with its done when> — go?
```

Each line starts with its label in plain text; no emoji or symbol precedes
a label. The closing line, after the question, names the closer in the
user's language, once: `จบงานเรียก aegonex-exit` when the user writes
Thai, `end with aegonex-exit` otherwise.

## Never

- Never write code, a spec, a design document or an implementation plan.
  The roadmap is the plan at this altitude.
- Never commit. Whether the roadmap is committed is the user's word, at
  `aegonex-exit`.
- Never write or edit `HANDOFF.md`; exit owns it.
- Never ask two questions in one message, and never ask an eighth.

| Excuse | Reality |
|---|---|
| "One more question, to be thorough" | The write condition is the stop. Thoroughness lives in `done when`, not in the interview. |
| "Is this design OK before I write it?" | That is a question, it counts, and the brief's `go?` is the only approval. |
| "I'll write a spec so the steps are concrete" | A step is concrete when its `done when` is a command or a behaviour. A spec is a second file nobody owns. |
| "I'll sketch the code so the estimate is right" | No code before the step starts. Sizing is "fits one session", nothing finer. |
| "I'll commit the roadmap so it is safe" | It is on disk. Committing is the user's decision. |
| "The user said 'you decide', so I'll decide everything" | Decide that one thing, write `(agent's call)`, continue the order. |

## Red flags — stop, you are leaving the procedure

- A message with two question marks in it.
- A question numbered 8.
- A file being written whose name is not `ROADMAP.md`.
- `git commit` in a command.
- A step whose `done when` is "works", "is complete" or "looks good".

## Quick reference

| Situation | Plan does |
|---|---|
| No ROADMAP, first message already says the goal | skip question 1, ask from 2 |
| User answers "you decide" | decide, `(agent's call)` under Decisions, continue |
| Existing ROADMAP, M2 ticked, M3 empty | write M3's steps; M1, M2 and Decisions untouched |
| User names a feature mid-milestone | add it as a new milestone, not into the current one |
| Write condition met after three answers | stop asking, write, brief |
