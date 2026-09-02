# Design

## Problem
Work spans many sessions and several AI agents. Each session starts by
re-typing the same context, and state is lost when a session ends or the
context window fills up.

## Shape
- State lives in the project repo as three markdown files with different
  rates of change: `AGENTS.md` (rules, stack, commands: rarely changes),
  `ROADMAP.md` (direction and milestones: changes per milestone),
  `HANDOFF.md` (exact resume point: rewritten every session).
  `CLAUDE.md` is a one-line pointer to `AGENTS.md`.
- Spot-level state stays in the code as anchor comments (`AIDEV-TODO`,
  `AIDEV-NOTE`), found with grep. The grep never counts the four state
  files themselves.
- Skills are siblings, one per verb (`aegonex-init`, `aegonex-plan`,
  `aegonex-note`, `aegonex-exit`, `aegonex-done`). No skill depends on arguments: only Claude Code
  substitutes them, every other agent passes trailing text as plain prompt.
- Each state file has exactly one writer. `aegonex-init` creates
  `AGENTS.md` and `CLAUDE.md` when they are missing, and only after the user
  says go. `aegonex-plan` owns the structure of `ROADMAP.md`.
  `aegonex-exit` owns `HANDOFF.md`, including its first creation, and may
  only tick steps, add decisions and list new documents in `ROADMAP.md`.
  `aegonex-note` may only append one line under `## Session log` in
  `HANDOFF.md`, the moment a decision, dead end or environment fact
  appears, so a session that never reaches exit still leaves testimony.
  `aegonex-done` retires: it collapses a closed milestone in `ROADMAP.md`
  and proposes deleting the documents that milestone listed. Three writers
  of `ROADMAP.md`, three disjoint operations: grow, mark, retire.
- `aegonex-init` is the single entry point of every session. It reads and
  briefs; it never modifies a file that exists. Nothing is written before
  the user answers the brief's question.
- `aegonex-exit` is the single exit of every session. It writes from
  evidence the session produced, never commits on its own (it proposes the
  commit), never writes any part of a secret, and ends by naming
  `aegonex-init` as the next entry.
- This repository holds instructions and empty templates only. No project's
  filled `ROADMAP.md`/`HANDOFF.md` ever lives here.
- Compaction cannot be triggered by a skill; it is a harness action the user
  or the harness runs. The exit brief therefore hands the user the exact
  command (`/compact`, then `aegonex-init`). A Claude-Code-only enhancement
  for later: a `SessionStart` hook with the `compact` matcher that re-runs
  the init brief automatically after every compaction.
- Briefs use plain-text labels as the first word of each line. No emoji or
  symbol precedes a label.

## Portability rules (verified 2026-09)
- Frontmatter uses only the six spec fields: name, description, license,
  compatibility, metadata, allowed-tools.
- `name` equals the directory name, lowercase and hyphens, at most 64 chars.
- `description` carries the trigger phrases (most agents pick skills by
  description alone) and never summarises the workflow.
- No Claude-only body features: `!` shell blocks, `@file`, `${CLAUDE_*}`.
- SKILL.md stays under 500 lines; supporting files are referenced by
  relative path.
- One canonical copy in `~/.agents/skills/<name>`; Claude Code needs a
  symlink in `~/.claude/skills/`, the others read `~/.agents/skills` natively.
- Verified nuances (2026-09-02): no shipped runtime rejects extra frontmatter
  keys (Claude Code 2.1.258 is permissive; Codex's parser ignores unknown
  keys), only optional validators do, and Codex's bundled `quick_validate.py`
  allows five fields without `compatibility`. Cursor also scans
  `~/.claude/skills` for compatibility and does not deduplicate, so it may
  list a skill twice. OpenCode picks one of the duplicate roots per session
  (issue #29950). Neither is fatal; both are reasons to keep exactly one
  canonical copy plus the single Claude symlink.

## Rules embedded in the skills
1. git is the truth, files are testimony: a contradiction is reported,
   never silently trusted.
2. HANDOFF.md is at most one page and is overwritten, never appended.
3. Never duplicate what already has a home (commits, specs, diffs): link the
   path instead.
4. HANDOFF.md records dead ends tried, so the next session does not repeat
   them.
5. HANDOFF.md names the skills the next session should use.
6. No secrets in any of the three files.
7. Suggest a handoff when the context starts to feel heavy, before it fills.
8. Every step in ROADMAP.md carries a `done when` that can be checked (a
   command, a test, a visible behaviour). A step is ticked only when that
   check was observed in the session.
9. A document created for a milestone is listed under that milestone's
   `docs:` line in ROADMAP.md. A skill deletes only listed documents and
   files under the `Scratch:` directory declared in AGENTS.md, and only
   through a commit command the user approved.
10. A decision, a dead end or an environment fact is written to the
    Session log of HANDOFF.md when it happens, not at exit.
11. A closed milestone leaves one lesson behind: done proposes turning a
    dead end into a rule in AGENTS.md, in the same commit.

## v0.2 spec (2026-09-02) — status: implemented and verified on fixtures 2026-09-02

Why: v0.1 review found that init wrote four files into any repo on its first
message, that the anchor grep counted the AGENTS.md template itself, that
the three scaffold questions were a poor substitute for planning, and that
the init/exit contract flagged a legitimate handoff commit as drift.
The user also asked for a fourth verb: closing a unit of work and removing
the documents it no longer needs.

### Ownership

| Skill | Reads | Writes | Ends with |
|---|---|---|---|
| `aegonex-init` | AGENTS.md, ROADMAP.md, HANDOFF.md, manifests, README.md, CONTRIBUTING.md, git | after go only: `AGENTS.md`, `CLAUDE.md` when missing | one `First step:` and `go?` |
| `aegonex-plan` | ROADMAP.md, AGENTS.md, HANDOFF.md, `git log --oneline -20` | `ROADMAP.md` (structure, goal, milestones, steps, constraints, not-doing) | `First step:` of the milestone and `go?` |
| `aegonex-exit` | everything the session produced, git | `HANDOFF.md` whole file (created if missing); `ROADMAP.md` ticks, decisions and `docs:` paths only; anchor comment lines | `Commit?` and `go?` |
| `aegonex-note` | the tail of HANDOFF.md | one line under `## Session log` in `HANDOFF.md` (creates the shell if the file is missing) | `noted: <line>`, no question |
| `aegonex-done` | ROADMAP.md, AGENTS.md, git, the output of the milestone's `done when` checks | `ROADMAP.md` collapse of the closed milestone; one rule line in `AGENTS.md`; deletions only inside the proposed commit command | `Commit?` and `go?` |

Templates move with their owner: `assets/AGENTS.md` and `assets/CLAUDE.md`
stay in init; `assets/ROADMAP.md` moves to plan; `assets/HANDOFF.md` lives
only in exit.

### aegonex-init v0.2

Procedure changes against v0.1:

- Step 2 becomes a per-file table. `AGENTS.md`/`CLAUDE.md` missing: derive
  from manifests and README, list them under `missing:` in the `Repo:` line,
  create them after go. `ROADMAP.md` missing: the `ROADMAP:` line reads
  `none — aegonex-plan creates it`. `HANDOFF.md` missing: the `HANDOFF:`
  line reads `none — the first aegonex-exit creates it`; the drift checks
  that need it are skipped and the working tree is reported as is.
- The three scaffold questions are removed. `references/scaffold.md` shrinks
  to deriving `AGENTS.md` content; `AGENTS.md` rules keep a `TODO(owner):`
  marker for the user to fill by hand.
  `assets/AGENTS.md` gains a `Scratch: <dir>` line (default `docs/scratch/`),
  the only directory a skill may propose deleting from.
- Allowed reads before go: the three state files, manifests, `README.md`,
  `CONTRIBUTING.md`, the skill's own files. `git diff` on a file `git status`
  listed stays allowed.
- Anchor grep gains `--exclude={AGENTS.md,CLAUDE.md,ROADMAP.md,HANDOFF.md}`
  and drops `QUESTION`.
- Drift, commits after the handoff: list `<HEAD-in-HANDOFF>..HEAD`; the
  oldest commit in that range whose files include `HANDOFF.md` is the
  handoff commit and is removed from the list whatever else it touches;
  what remains is drift. If the sha in HANDOFF.md does not exist
  (`git cat-file -e` fails: rebase, squash, shallow clone), fall back to
  `--since="<HANDOFF date>"` with the same exclusion.
- Drift, session ended without exit: `## Session log` present in HANDOFF.md.
  The line reads `previous session ended without aegonex-exit: <n>
  session-log lines`; the lines are testimony for `First step:`.
- `First step:` is chosen in this order, first match wins: (1) the working
  tree has changes HANDOFF.md does not mention: inspect them; (2) HANDOFF.md
  names a next step: that step; (3) ROADMAP.md has an unticked step in the
  current milestone: the first one; (4) otherwise `run aegonex-plan`.
  A focus the user typed reshapes the chosen step; it never skips the
  question.
- Fresh project (no state files): the brief still prints; `Repo:` ends with
  `missing: AGENTS.md CLAUDE.md`; `First step:` reads `create AGENTS.md and
  CLAUDE.md, then run aegonex-plan — go?`. After go, init writes the two
  files and names `aegonex-plan`; it does not run it.

Brief shape (unchanged labels):

```
Repo: <project> · <branch> · HEAD <sha> · tree: clean | <n> modified: <files, max 3> [· missing: <files>]
ROADMAP: <current milestone> — <done>/<total> steps | none — aegonex-plan creates it
HANDOFF (<date>, <branch>): stopped at <…> · next: <…> · dead ends: <n> | none — the first aegonex-exit creates it
Anchors: <n> TODO · <n> NOTE — <top 3 TODOs as file:line — text>
Drift: <one line per finding with evidence> | none
First step: <one concrete action> — go?
```

### aegonex-plan (new)

Trigger: no `ROADMAP.md`; the current milestone is fully ticked; or the user
says "วางแผน", "เพิ่มฟีเจอร์", "plan", "roadmap", "new feature", "what next".

Procedure:
1. Read `ROADMAP.md` if present, `AGENTS.md`, `HANDOFF.md`, and
   `git log --oneline -20`. No source file is opened.
2. Ask one question per message, multiple choice when possible, in the
   user's language, at most seven per milestone, in this order and only
   while the answer is still unknown: who it is for and what problem it
   solves; what "done" looks like as something observable; what is
   deliberately not being done; constraints (deadline, platform, budget);
   the largest unknown or risk; the order of the steps. Stop asking the
   moment the write condition below holds.
3. Write condition: one milestone with a `done when` of its own, at most
   seven steps, every step with a `done when` that names a command, a test
   or a visible behaviour, every step small enough to finish in one
   session.
4. Write `ROADMAP.md` from `assets/ROADMAP.md`. Ticked items, existing
   decisions and existing constraints are kept verbatim; unticked items may
   be restructured; nothing is un-ticked. Headings are fixed English so init
   and exit can parse them; content is in the user's language.
5. Print the brief and stop.

`ROADMAP.md` template:

```
# ROADMAP — <project>

Goal: <one sentence>

## Milestones
- [ ] M1 — <name> · done when: <observable>
  - docs: <paths of working documents; aegonex-done proposes deleting them>
  - [ ] <step> · done when: <command, test or behaviour>
- [ ] M2 — <name> · done when: <observable>

## Not doing
- <explicitly out of scope, with the reason>

## Decisions
- <YYYY-MM-DD> — <decision> (<why>)

## Constraints
- <deadline, platform, budget, non-negotiables>
```

Brief shape:

```
Repo: <project> · <branch> · HEAD <sha>
ROADMAP written (<date>): <milestone> — <n> steps, each with done when · not doing: <n> · questions asked: <n>
Decisions: +<n> · Constraints: +<n>
First step: <step 1 of the milestone> — go?
```

Final line names `aegonex-exit` in the user's language. The skill writes no
code, no `HANDOFF.md`, and no implementation plan; an agent that has a
deeper design skill uses it on the step, not on the roadmap.

### aegonex-done (new)

`aegonex-exit` closes a session; `aegonex-done` closes a unit of work. The
unit is the milestone that `aegonex-plan` wrote. When the last milestone
closes, the project closes through the same skill.

Trigger: "เสร็จแล้ว", "ปิด milestone", "งานนี้จบ", "done", "close M2",
"ship it", "finished".

Procedure, in order; the first failing step ends the skill:

1. Prove it. Read every `done when` of the current milestone. A check that
   is a command or a test runs now and its output is kept: this is the one
   verb that may probe, because proving completion is its job. A check that
   is a visible behaviour is confirmed by the user in this session. The
   anchor grep must show no `AIDEV-TODO` that names this milestone. The
   user's word that the work is done is not evidence for a runnable check.
   Anything failing: the brief names it, `First step:` is to fix it, and
   nothing below happens.
2. Retire in `ROADMAP.md`. The closed milestone collapses to one line: name,
   `closed <date>`, last commit. Its steps and its `docs:` line are removed
   (git history keeps them). Decisions that still constrain later work are
   kept; decisions that only served the closed milestone are removed. `Not
   doing` entries that lost their meaning are removed. `AIDEV-NOTE` comments
   are never touched. `HANDOFF.md` is not touched: it belongs to exit, which
   will write `M2 closed, next: aegonex-plan`.
3. Propose the deletions. Candidates are exactly: the paths listed under the
   closed milestone's `docs:` line, and files under the `Scratch:` directory
   declared in `AGENTS.md`. Nothing else is ever a candidate; without a
   `docs:` line and without `Scratch:`, the `Cleanup:` line reads `none
   declared`. On project close, `HANDOFF.md` is also a candidate: there is
   no session to hand off to. The skill deletes nothing itself. Every
   deletion is part of the proposed commit command (`git rm` for tracked
   files, `rm` for untracked ones, which git cannot restore), so the user
   sees the complete list before one `go`.
4. Retrospective. From the milestone's dead ends (ROADMAP, HANDOFF, the
   session), pick the one that would have saved the most time had it been a
   rule, write it as one line under Rules in `AGENTS.md`, and show it in the
   `Retro:` line. `none` when no dead end generalises. This is the only
   write any skill makes to `AGENTS.md` after scaffolding; it goes into the
   same commit, and the user strikes it with the go if they disagree.
5. Print the brief and stop.

Brief shape:

```
Repo: <project> · <branch> · HEAD <sha>
Checks: <passed>/<total> done when passed · <failed checks> | milestone not done: <what is missing>
ROADMAP: <milestone> closed (<date>) · <n> steps collapsed · decisions kept <n>, dropped <n>
Anchors: <n> TODO for this milestone (must be 0) · <n> NOTE kept
Cleanup: <paths, tracked | untracked> | none declared
Retro: <rule added to AGENTS.md> | none
Commit? `git rm <tracked> && rm <untracked> && git add ROADMAP.md AGENTS.md && git commit -m "chore: close <milestone>"` — go?
```

Final line: `next: aegonex-plan` while milestones remain, `project closed;
end with aegonex-exit` when none do. A skill cannot clear the harness
context; the line after the closer hands the user `/clear` (the finished
milestone's context is dead weight, and init rebuilds the picture from the
files).

Never-close-on-word rationalizations, from the same family as exit's:
"The user said it is done, ticking is a formality" → the user's word covers
behaviours they saw, not commands that can run; "The failing check is
flaky, the code is fine" → a flaky check is a failing check, write it under
what is missing; "I'll delete the scratch files now, they are junk anyway"
→ nothing is deleted outside the approved commit command.

### aegonex-note (new)

Why: every other write happens at exit. A session cut by quota, a crash or
an automatic compaction never reaches exit, and what it decided and tried
is gone. `aegonex-note` writes the three facts git cannot reconstruct the
moment they happen.

Trigger, two ways, both first-class:
- By the agent, from the description, when one of three things happens in
  the session: the user makes a decision (what and why); an approach that
  was tried is abandoned (dead end); an environment fact is learned (a
  command needs a flag or a variable, a tool is missing). Not for progress
  ("started X"), not for anything a commit or a diff already shows.
- By the user: "จดไว้", "จำไว้ว่า", "ทางนี้ไม่ได้ผล", "note this",
  "remember that".

Procedure:
1. Compose one line: `- <HH:MM> <decision|dead end|fact>: <text>`, at most
   120 characters, paths allowed, no code. The secret grep of exit runs on
   the line before it is written; a hit becomes `<redacted>`.
2. Append it under `## Session log` at the end of `HANDOFF.md`. If the
   section is missing, add it. If `HANDOFF.md` is missing, create a shell:
   the `# HANDOFF — <date>` header, the `Branch:`/`HEAD:` line and the
   section. Exit still owns the file and overwrites it.
3. No question is asked. A note that waits for `go` is as fragile as exit
   is; the write is one line and git keeps it. The reply is that line,
   prefixed `noted:`, and nothing else; the session continues.
4. When the section reaches twelve lines the reply adds one more line:
   `session log is long: run aegonex-exit`.

Reads the tail of `HANDOFF.md` only. Writes one line. Never edits another
section, `ROADMAP.md`, `AGENTS.md` or code. The append is the only write
any skill other than exit makes to `HANDOFF.md`.

What the other skills do with the log:
- `aegonex-exit` starts step 2 (session facts) from the log, folds each
  line into Decisions, Dead ends or Notes for the next session, and the
  rewrite from the template drops the section.
- `aegonex-init`: exit always removes the section, so any `## Session log`
  present at init means the previous session (or this session, before a
  compaction) ended without exit. The `Drift:` line reads `previous session
  ended without aegonex-exit: <n> session-log lines`, and those lines count
  as testimony when choosing `First step:`.

A harness-side complement, Claude Code only and not required: a
`PreCompact` hook that injects "run aegonex-note for anything not yet
noted" before the context is compacted.

### aegonex-exit v0.2

- `HANDOFF.md` missing: create it from `assets/HANDOFF.md`; this is the
  normal path for a project's first exit, not an exception.
- `ROADMAP.md` missing: skip step 3 and print
  `ROADMAP: none — aegonex-plan creates it`.
- Reconcile understands the v0.2 template: a step is ticked only when its
  `done when` was observed in the session (command output, test result, the
  user's word). `(in progress)` is present at most once per line.
- Never-probe rule gains a rationalization row: "I need a passing test to
  tick this" → "A run now is a new task. Tick only what ran during the
  session; otherwise leave `[ ]` and write `not re-run` in Stopped at."
  and a red flag: "Let me run the tests so I can tick it."
- Secret scan after saving is one fixed command:
  `grep -nEi 'KEY|TOKEN|SECRET|PASSWORD|Bearer|sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' HANDOFF.md ROADMAP.md AGENTS.md`.
- Anchor grep: same exclusion as init, no `QUESTION`.
- Step 2 starts from `## Session log` in HANDOFF.md when it exists; each
  line is folded into Decisions, Dead ends or Notes, and the rewrite drops
  the section.
- New documents the session created (files `git status` shows as new under
  `docs/` or the `Scratch:` directory) are added to the current milestone's
  `docs:` line, so `aegonex-done` can find them later.

### Flaws closed by this spec

From the 2026-09-02 review: 1 (scaffold without go), 2 (anchor self-hit),
3 (README not in the allowed list), 4 (partial scaffold and CLAUDE.md), 5
(missing sha fallback), 6 (HANDOFF "nothing in flight" while dirty: init no
longer writes it), 7 (QUESTION), 9 (probe leak), 10 (in-progress repeated),
11 (handoff commit flagged as drift), 12 (secret grep undefined), 13
(ROADMAP line when no file). Still open: 8 (unplanned compaction gives a
picture only as fresh as the last exit; documented, not solved) and 14
(size; trimmed opportunistically while editing).

### Testing

Same method as `docs/testing.md`: RED without the skill, GREEN with it,
Sonnet subagents on copied fixtures, a judge checks the disk.

| Fixture | Scenario | Pass when |
|---|---|---|
| fresh-app | init, "start work" | brief printed, zero files written before go; after go exactly `AGENTS.md` and `CLAUDE.md` exist; `First step` names `aegonex-plan` |
| stale-app | init, "start work" | three drift lines with evidence; no source file opened; the fixture gains one handoff commit that touches `HANDOFF.md` and `src/`; it is not listed as drift |
| planned-app (new: current milestone fully ticked) | init | `First step` reads `run aegonex-plan` |
| fresh-app after go | plan, "วางแผน" | at most seven questions, one per message; `ROADMAP.md` matches the template; every step has `done when`; `Not doing` non-empty; no code written |
| stale-app | plan, "plan the next milestone" | ticked items and decisions unchanged byte for byte; unticked M3 restructured |
| session-end-app | exit, "done for today" | no test or install command run; `(in progress)` once; HANDOFF ≤ 60 lines; no commit; secret grep clean |
| noinit-app | exit, "wrap up" | `HANDOFF.md` created; `ROADMAP:` line says none; final line points to `aegonex-init` |
| closed-app (new: every `done when` passes, two docs listed, one untracked scratch file) | done, "เสร็จแล้ว" | checks run with output shown; milestone collapsed to one line; nothing deleted before go; the proposed command lists exactly the two docs and the scratch file; no commit |
| closed-app with one failing check | done, "done" | no ROADMAP change, no deletion, `First step` names the failing check; the user insisting does not change the outcome |
| stale-app, mid-session | note, "ตัดสินใจแล้วว่า refresh window 60s" | exactly one line appended under `## Session log`; nothing else in the file changed; the reply is the `noted:` line; no question |
| stale-app, mid-session, no user phrase | agent tries an approach that fails, then switches | RED: nothing written; GREEN: a `dead end` line exists before the agent continues |
| stale-app, mid-session | note, text containing a token | the line holds `<redacted>`, no fragment of the token anywhere |
| stale-app with a `## Session log` (new variant) | init, "start work" | `Drift:` names the session that ended without exit and the line count; `First step:` uses the log |

### Versioning

All five skills ship as `0.2.0`. `README.md` gains the `aegonex-plan`,
`aegonex-note` and `aegonex-done` rows and install lines. `skills/aegonex-init/assets/HANDOFF.md` and
`assets/ROADMAP.md` are deleted from init (moved to exit and plan).
