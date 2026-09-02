# Testing a skill

Skills are tested like code: watch an agent fail without the skill, write
the skill against those failures, watch it pass, close the loopholes.

## Fixtures

`tests/fixtures/make-fixtures.sh <dir>` builds the two roots; the other
builders take `<dir> <src-dir>` and copy from `stale-app` or `fresh-app`.
Copy a fixture per run; agents mutate them.

| Fixture | Builder | State |
|---|---|---|
| `stale-app` | `make-fixtures.sh` | state files present; HANDOFF written on `feat/auth-refresh` with `HEAD:`, then a handoff commit touching `HANDOFF.md` and `src/`, then a drift commit; checked out on `fix/db-race` with a dirty `src/db.ts` |
| `fresh-app` | `make-fixtures.sh` | no state files |
| `session-end-app` | `make-exit-fixture.sh` | stale-app after a day of work: a committed test, an uncommitted half-done refresh path, the open step already marked `(in progress)` |
| `noinit-app` | `make-noinit-fixture.sh` | fresh-app with uncommitted work and no state files |
| `planned-app` | `make-planned-fixture.sh` | M2 fully ticked, M3 has no steps: init must point to `aegonex-plan` |
| `closed-app` | `make-closed-fixture.sh` | M2 steps ticked, every `done when` a runnable `bash tests/check-*.sh`, two docs on the `docs:` line, one untracked file under `docs/scratch/` |
| `closed-app-failing` | `make-closed-fixture.sh … --failing` | same, with one check that fails |
| `sessionlog-app` | `make-sessionlog-fixture.sh` | HANDOFF with a `## Session log` left by a session that never ran exit, and a `HEAD:` sha that no longer exists |

## Method

1. RED: give a cheap model (Sonnet) the fixture path and the user's message
   only. Record what it reads, runs, writes and replies. For a skill that
   already exists, RED runs the previous version (`git archive HEAD` into a
   scratch dir).
2. GREEN: same runs, with "the user invoked <skill>; read SKILL.md and
   follow it". `tests/judge.sh <kind> <brief-file> <fixture>` checks the
   brief's shape (no emoji, labels, one `go?`, the closer on the last line)
   and prints disk facts; the scenario's own assertions run on those facts.
3. REFACTOR: every deviation becomes a red flag, a rationalization row or a
   required slot in the template, then the affected scenarios run again.

Two scenario shapes need a trick:
- `aegonex-plan` asks questions one at a time, and a subagent cannot wait for
  a user. The prompt scripts the user's answers in order and tells the agent
  to write each question it would ask into its report before taking the next
  answer. The judge counts the questions.
- `aegonex-note` must trigger from its description alone. The prompt lists
  all five skills with their descriptions and paths, describes a situation
  (an approach that just failed) and a user message that names no skill.
  Pass means the agent read the note skill and wrote the line before
  continuing.

## Results that shaped v0.1 (2026-09-02)

Without the skills, agents opened source files before the user said go,
missed commits newer than the handoff, closed sessions by committing on
their own (3/3) and wrote fragments of a planted secret into HANDOFF.md
(2/3).

## Results that shaped v0.2 (2026-09-02)

- v0.1 init wrote four files into a fresh repo before go and its anchor grep
  matched its own AGENTS.md template. v0.2 init creates nothing before go and
  only `AGENTS.md` and `CLAUDE.md` after it.
- Without a plan skill, the agent asked nine questions (three of them
  approval questions), wrote a 1000-line implementation plan and a spec
  under `docs/` instead of `ROADMAP.md`, and committed both on its own.
- Without a note skill, a decision stated mid-session went into ROADMAP's
  Decisions after the agent had implemented the whole feature; nothing
  reached HANDOFF.md.
- v0.1 exit, in one run, ran `npx vitest run` during the close and installed
  `node_modules`; the agent reported its own violation. v0.2 names that
  rationalization.
- Without a done skill, the agent ran the milestone's checks (good), then
  invoked exit on its own, rewrote HANDOFF.md and lost its dead ends, never
  collapsed the milestone, and refused to structure the deletions.
