# <project name>

## Stack
<languages, frameworks, runtime versions>

## Commands
- `<dev command>` — start locally
- `<test command>` — run tests
- `<build command>` — build
- `<lint command>` — lint

## Layout
Scratch: docs/scratch/
(disposable working files live there; `aegonex-done` proposes deleting them
and nothing outside it, or outside a milestone's `docs:` line, is ever
deleted by a skill)

## Rules
- TODO(owner): rules the agent must never break in this repo

## Session ritual
- Start every session with `aegonex-init`; plan a milestone with
  `aegonex-plan`; write decisions, dead ends and environment facts with
  `aegonex-note` the moment they happen; end the session with
  `aegonex-exit`; close a finished milestone with `aegonex-done`.
- Without those skills: read `HANDOFF.md`, then `ROADMAP.md`, check
  `git status`, report drift, and propose one first step before touching code.
- `HANDOFF.md` is at most one page and is rewritten, never appended.
- Anchor comments in code: `AIDEV-TODO:` marks pending work at that spot,
  `AIDEV-NOTE:` marks an invariant. Delete a TODO when the work is done.
- git is the truth, these files are testimony: report contradictions.
- No secrets in any of these files.
