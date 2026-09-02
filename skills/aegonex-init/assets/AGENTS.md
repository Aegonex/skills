# <project name>

## Stack
<languages, frameworks, runtime versions>

## Commands
- `<dev command>` — start locally
- `<test command>` — run tests
- `<build command>` — build
- `<lint command>` — lint

## Rules
- TODO(owner): rules the agent must never break in this repo

## Session ritual
- Start every session with the `aegonex-init` skill; end it with `aegonex-exit`.
- Without those skills: read `HANDOFF.md`, then `ROADMAP.md`, check
  `git status`, report drift, and propose one first step before touching code.
- `HANDOFF.md` is at most one page and is rewritten, never appended.
- Anchor comments in code: `AIDEV-TODO:` marks pending work at that spot,
  `AIDEV-NOTE:` marks an invariant. Delete a TODO when the work is done.
- git is the truth, these files are testimony: report contradictions.
- No secrets in any of these files.
