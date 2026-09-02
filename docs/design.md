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
  `AIDEV-NOTE`), found with grep.
- Skills are siblings, one per verb (`aegonex-init`, `aegonex-exit`, ...).
  No skill depends on arguments: only Claude Code substitutes them, every
  other agent passes trailing text as plain prompt.
- `aegonex-init` is the single entry point of every session. It is
  idempotent: it scaffolds the three files when they are missing and briefs
  from them when they exist. It reads; it never writes state.
- `aegonex-exit` is the single exit of every session and the only writer of
  `ROADMAP.md` and `HANDOFF.md`. It writes from evidence the session produced,
  never commits on its own (it proposes the commit), never writes any part of
  a secret, and ends by naming `aegonex-init` as the next entry.
- This repository holds instructions and empty templates only. No project's
  filled `ROADMAP.md`/`HANDOFF.md` ever lives here.
- Compaction cannot be triggered by a skill; it is a harness action the user
  or the harness runs. The exit brief therefore hands the user the exact
  command (`/compact`, then `aegonex-init`). A Claude-Code-only enhancement
  for later: a `SessionStart` hook with the `compact` matcher that re-runs
  the init brief automatically after every compaction.

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
