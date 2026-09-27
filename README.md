# Aegonex skills

Personal, cross-agent skills. One canonical copy per skill, written to the
[Agent Skills](https://agentskills.io) spec, so the same `SKILL.md` works in
Claude Code, Codex CLI, Cursor, OpenCode and GitHub Copilot CLI.

This repository contains instructions and empty templates only. Project state
(ROADMAP.md, HANDOFF.md) lives in each project's own repository, never here.

## Install

```bash
npx skills add Aegonex/skills
```

## Skills

Five verbs, one lifecycle: open a session, plan a milestone, note what git
cannot reconstruct, close the session, close the milestone.

| Skill | Use when | Writes |
|---|---|---|
| `aegonex-init` | a session starts: briefs from AGENTS.md, ROADMAP.md, HANDOFF.md and git, proposes one first step, waits for go | on go: `AGENTS.md` and `CLAUDE.md` (created, or two sections appended) in one setup commit; opens the unit folder |
| `aegonex-plan` | the next milestone needs planning: at most seven questions, one at a time | on go: `ROADMAP.md` in the milestone folder, every step with a `done when`, committed there |
| `aegonex-note` | a decision, a dead end or an environment fact appears, mid-session | one line under `## Session log` in the open milestone folder's `HANDOFF.md`, no question asked |
| `aegonex-exit` | a session ends or is handed off, or unfinished work must be pushed | `HANDOFF.md` whole, `ROADMAP.md` ticks and decisions, committed on go; lands unfinished work only when asked |
| `aegonex-done` | a milestone or task is finished, or its pull request was merged | runs its checks, collapses it in `ROADMAP.md`, then on go closes, lands (or opens a pull request) and removes the folder and branch |

## How work flows

Every change, even a one-line fix, happens in its own folder: a git worktree
at `.worktrees/<unit>` on branch `aegonex/<unit>` (`m2` for milestone M2,
`t-<slug>` for other work). The main folder stays on the base branch. Big
work is split into parts that subagents write in parallel, each in its own
folder, and a separate reviewer checks every part before it is merged back.
Landing on the base branch, pushing and removing the folder happen on a go
that names them; a protected base branch gets a pull request instead, and
unfinished work that was pushed asks before its folder is removed. The
rules live in two sections of each project's `AGENTS.md`, so any agent
follows them, with or without these skills.

Every brief is a short table in the user's language that ends with one
question (`aegonex-note` and the report after a go answer in a line or two
and ask nothing). In Claude Code the answer is a **go** button; elsewhere,
type `go` (or ok, yes, ได้, ลุย). Before it, a skill writes nothing but
its own notes: `aegonex-exit` writes the handoff the go will commit, and
`aegonex-note` appends its line.

Design and contracts: `docs/design.md`. How the skills are tested:
`docs/testing.md`.
