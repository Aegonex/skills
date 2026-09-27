---
name: aegonex-plan
description: Use when a project needs its next milestone planned — there is no ROADMAP.md, the last milestone was closed by aegonex-done, aegonex-init said "run aegonex-plan", or the user says "วางแผน", "เพิ่มฟีเจอร์", "plan", "roadmap", "new feature", "what comes after this milestone". Also use when a feature request arrives that is bigger than one step.
license: MIT
metadata:
  author: Aegonex
  version: "0.4.1"
---

# aegonex-plan

## Overview

This skill owns the structure of `ROADMAP.md`: the goal, the milestones,
their steps, what "done" looks like for each, what is deliberately not being
done, decisions and constraints. It asks a few questions, one at a time,
and stops asking the moment it can write one milestone whose every step
has a check. On go it writes the file and hands the user the first step.

Core principle: **a step without a `done when` is not a step.** The check
is what `aegonex-exit` ticks against and what `aegonex-done` runs. Every
step must be small enough to finish in one session, because `HANDOFF.md`
carries one next step at a time.

The artifact is `ROADMAP.md` alone: no spec, implementation plan, code or
`HANDOFF.md`. It is written only after go, in the milestone's own folder
`.worktrees/m<n>` on branch `aegonex/m<n>` (`AGENTS.md` **Open**), never in the
main folder. A deeper design skill is used on a step when it starts, never on the roadmap.

## When to use

- `ROADMAP.md` does not exist, or the last milestone was closed.
- The user asks to plan or add a feature.

Not for: opening a session (`aegonex-init`), recording a single decision
(`aegonex-note`), closing a milestone (`aegonex-done`), or designing the
inside of one step (the agent's own design tools, after the step starts).

## Language

Every question and reply, labels and options included (`go` stays `go`), is in
the language of the user's message; a message with no language of its own
(only the skill's name, or a bare answer such as `go`, `ok`, `yes`) takes the
language of the conversation so far, else that of `ROADMAP.md`, else English.
This skill gives labels in English and Thai; for another language, translate
the English. `ROADMAP.md` content follows the same language; its headings do not (step 4).

## Procedure

### 1. Read the testimony

Every command, reads included, is its own tool call on one line: no `&&`, `||` or `;`; an exit code
comes from the tool result, never `; echo $?` or `|| true`. Every git command is `git -C "<absolute folder>"`,
even when the shell or a harness prefix already stands in that folder; never `cd` to run one.
`git -C "<current folder>" worktree list --porcelain`: its first `worktree ` path is `<main>`;
a `branch refs/heads/aegonex/m<n>` line marks the open milestone folder. Read `ROADMAP.md`
and `HANDOFF.md` from that folder, else from `<main>`, plus `<main>`'s `AGENTS.md` and
`git -C "<main>" log --oneline -20`; `date +%F` (PowerShell: `Get-Date -Format yyyy-MM-dd`)
gives today's date for new Decisions lines. Manifests (`package.json` and the like) may be
read for the stack; no source file is opened: the roadmap is built from what the user wants,
not from what the code does.

Stop with one line, no brief and no question, when:
- `AGENTS.md` has no `## Working mode (aegonex 0.4)`: `run aegonex-init first` / `เรียก aegonex-init ก่อน`;
- the open milestone is closed
  (`git -C "<folder>" log -1 --first-parent --no-merges --format=%s` prints
  `chore: close m<n>`) and `<remote>/aegonex/m<n>` exists: `m<n> waits for
  its pull request; merge it, then tell aegonex-done (a task can start
  meanwhile)` / `m<n> รอ merge pull request: merge แล้วบอก aegonex-done
  (ระหว่างนี้เริ่มงานย่อย t- ได้)`; closed without it: `run aegonex-done:
  m<n> is closed but not landed` / `เรียก aegonex-done: m<n> ปิดแล้วแต่ยังไม่ land`;
- the open milestone has every step ticked: `run aegonex-done first: M<n>
  has every step ticked` / `เรียก aegonex-done ก่อน: M<n> ทำครบทุกขั้นแล้ว`.
With a milestone folder open and unticked steps left, plan changes that
milestone or adds later milestone lines; it never opens a second one.

### 2. Ask, one question at a time

One question at a time, never a list. If your harness has a tool that asks
the user a multiple-choice question (Claude Code: `AskUserQuestion`), ask
each question with it: one question per call, two to four short options with
the likely answer first; the tool adds a free-text answer by itself.
Otherwise ask in a message of its own, with lettered options when they fit.
At most seven questions per milestone, counting every question of any kind.
Ask only what the write condition (step 3) still needs, in this order; the list sets the
order and is never a checklist to complete. Before the first question and after each answer,
compose the milestone from the files and the messages so far and check step 3 first: when it
holds, stop asking, even if questions remain; otherwise ask the next listed question step 3 still needs.

1. What should it let its users do? Asked only when the first message does not
   say who uses it and what it does.
2. What does "done" look like, as something a person can see or a command can check?
3. What is deliberately not being done?
4. Constraints: deadline, platform, budget, rules that cannot move. An answer of none
   (no deadline, no constraint) adds no Constraints line and no Constraints row in the brief.
5. The largest unknown or risk.
6. The order of the steps.

### 3. Write condition

A detail a step needs that the user has not given (order, data source, stack, or a structure
the user did not show, such as a route path or a menu), or anything answered "ไม่รู้" or
"you decide", is your call: decide it, record it under Decisions in the composed file with
`(agent's call)`, move on, and never ask about it again; a step never assumes one without that
Decisions line. Questions 4-6 are asked only when a step or its `done when` cannot be
written without the answer. The condition holds when all of these are true:
- one milestone has its own `done when`, observable by a person or a command;
- it has at most seven steps;
- every step has a `done when` naming a command, a test or a visible behaviour;
- every step is small enough to finish in one session;
- `Not doing` has at least one line, or the user explicitly said nothing is out of scope.

### 4. Compose ROADMAP.md

Compose the file now from `assets/ROADMAP.md`; it is written on go (step 6). Headings are fixed English, exactly as in
the template, so `aegonex-init`, `aegonex-exit` and `aegonex-done` can parse them; the content is in the user's language.

| Situation | Do |
|---|---|
| No `ROADMAP.md` | write the whole file: Goal, the milestone (M1), later milestones as one line each with a `done when` if known, Not doing, Decisions, Constraints |
| `ROADMAP.md` exists | keep every ticked line, every existing Decisions line and every Constraints line byte for byte; restructure only unticked milestones and steps; never un-tick; add, never rewrite, decisions |
| A `docs:` line | keep it; add a path only for a document the user named |

Step shape: `- [ ] <step> · done when: <command, test or behaviour>`.
Milestone shape: `- [ ] M<n> — <name> · done when: <observable>`.

The file stays under two pages. Paths and commands, not prose about how.

### 5. The brief

Written for someone who approves the plan from this reply alone; print it as markdown, not in a code
block, so the tables render:

```
**Planned: <M> <name>** (goes to `.worktrees/m<n>/ROADMAP.md`)
Done when: <the milestone's done when, in words>

| # | Step | Done when |
|---|---|---|
| 1 | <step> | <its check> |

| Item | Detail |
|---|---|
| <row label> | <what it says> |
```

The steps table lists every step of the milestone. The second table holds only the rows
that have something to say, in this order, and is left out when none do:

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| Not doing / ไม่ทำรอบนี้ | each item, separated by `;`, with its reason only when the user gave one (never a restatement such as "not this round") | `Not doing` has lines |
| My call / ผมเลือกให้ | each `(agent's call)` decision with its why | any was added this time |
| Constraints / ข้อจำกัด | the constraints added this time | any were added |
| Later / ถัดไป | later milestones, by name | the roadmap has any |
| Work folder / โฟลเดอร์งาน | `.worktrees/m<n>`, `new` / `ใหม่` when go opens it | always |

Thai for the fixed parts: `**วางแผนแล้ว: <M> <name>** (จะเขียนลง .worktrees/m<n>/ROADMAP.md)`,
`เสร็จเมื่อ:`, `| # | ขั้น | ผ่านเมื่อ |`, `| เรื่อง | รายละเอียด |`. Paths and
commands go in backticks. No emoji or icons. Not shown: the HEAD sha, the
number of questions asked, counts of decisions or constraints.

The question comes last, once, and nothing follows it:
- With a multiple-choice question tool: print the brief, then ask
  `Commit this plan?` / `commit แผนนี้เลยไหม?`, options `go` (commit, then
  stop) and `Change the plan` / `แก้แผน`.
- Otherwise the reply ends with this line, alone, after a blank line:
  `Reply **go** to commit this plan, or tell me what to change.` /
  `พิมพ์ **go** เพื่อ commit แผนนี้ หรือบอกว่าอยากแก้แผนตรงไหน`

A change request changes the composed file and prints the brief again; it is not one of the seven questions.

### 6. On go

Any clear yes is go (go, ok, yes, ได้, โอเค, ลุย):
1. no milestone folder is open: **Open** `m<n>`, `<n>` being the planned milestone, as the
   `Working mode` section of `AGENTS.md` says (or adopt a harness folder as it says). A new
   `aegonex/m<n>` whose `<remote>/aegonex/m<n>` exists stops:
   `by hand: delete aegonex/m<n> on the host, then git -C "<main>" fetch --prune <remote>`;
2. write `ROADMAP.md` in that folder, then `git -C "<folder>" add -- ROADMAP.md`
   and `git -C "<folder>" commit -m "docs: plan M<n>" -- ROADMAP.md`;
3. reply in at most three lines of plain text (no outer code span), no table and no question, then stop:
   `Opened .worktrees/m<n> on aegonex/m<n> and committed ROADMAP.md (docs: plan M<n>). Step <k>: <step> · done when: <check>.` /
   `เปิด .worktrees/m<n> บน aegonex/m<n> และ commit ROADMAP.md แล้ว (docs: plan M<n>) ขั้นที่ <k>: <step> · ผ่านเมื่อ: <check>`,
   `<k>` the first unticked step (1 in a new milestone); a folder already open reads `Committed ROADMAP.md in` / `commit ROADMAP.md แล้วใน`.
   A commit after the plan's, shown by `git -C "<folder>" log --oneline <plan sha>..HEAD`, is named on one more line, `;` between them.
   That step starts on the user's next message, under the `Leader mode` section of `AGENTS.md`.

## Never

- Never write code, a spec, a design document or an implementation plan.
  The roadmap is the plan at this altitude.
- Never write before go; on go, commit only `ROADMAP.md`, in the milestone
  folder, and start no step: the next step waits for the user's next message.
- Never write or edit `HANDOFF.md`; exit owns it.
- Never ask two questions in one message or one tool call, nor an eighth.

| Excuse | Reality |
|---|---|
| "One more question, to be thorough" | The write condition is the stop. Thoroughness lives in `done when`, not in the interview. |
| "Is this design OK before I write it?" | That is a question, it counts, and the brief's closing question is the only approval. |
| "I'll write a spec so the steps are concrete" | A step is concrete when its `done when` is a command or a behaviour. A spec is a second file nobody owns. |
| "I'll write the roadmap in the main folder, it is only a plan" | The plan is work: it goes in `.worktrees/m<n>`, on go. |
| "The user said 'you decide', so I'll decide everything" | Decide that one thing, record `(agent's call)`, and ask the next question only if the write condition still needs it. |

## Red flags — stop, you are leaving the procedure

- A message with two question marks in it.
- A question numbered 8.
- A write other than `ROADMAP.md`, or any write before go.
- A `git commit` other than `docs: plan M<n>`, `&&` `||` `;` in a command, or a git command without `-C "<absolute folder>"`.
- A step whose `done when` is "works", "is complete" or "looks good".

## Quick reference

| Situation | Plan does |
|---|---|
| First message says who uses it and what it does | skip question 1; ask only what step 3 still needs |
| User answers "you decide", or a step needs a detail not given | decide, `(agent's call)` under Decisions, no question, continue |
| User says go to the brief | Open `m<n>` unless open, commit only `ROADMAP.md` (`docs: plan M<n>`), reply in at most three lines naming the next step, stop |
| Existing ROADMAP, M2 ticked, M3 empty | write M3's steps; M1, M2 and Decisions untouched |
| User names a feature mid-milestone | add it as a later milestone line, not into the open one |
| The change fits in one step | not a milestone but task `t-<slug>`. The user named this skill or asked to plan it: say so, write nothing; it starts on the user's next message. Asked to make it: lead it now under Leader mode, not this skill |
| `m<n>` closed, its pull request waiting | one-line stop; tasks may start meanwhile |
