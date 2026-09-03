# Aegonex skills

Personal, cross-agent skills. One canonical copy per skill, written to the
[Agent Skills](https://agentskills.io) spec, so the same `SKILL.md` works in
Claude Code, Codex CLI, Cursor, OpenCode and GitHub Copilot CLI.

This repository contains instructions and empty templates only. Project state
(ROADMAP.md, HANDOFF.md) lives in each project's own repository, never here.

## Skills

Five verbs, one lifecycle: open a session, plan a milestone, note what git
cannot reconstruct, close the session, close the milestone.

| Skill | Use when | Writes |
|---|---|---|
| `aegonex-init` | a session starts: briefs from AGENTS.md, ROADMAP.md, HANDOFF.md and git, proposes one first step, waits for go | `AGENTS.md`, `CLAUDE.md` when missing, only after go |
| `aegonex-plan` | the next milestone needs planning: at most seven questions, one at a time | `ROADMAP.md`, every step with a `done when` |
| `aegonex-note` | a decision, a dead end or an environment fact appears, mid-session | one line under `## Session log` in `HANDOFF.md`, no question asked |
| `aegonex-exit` | a session ends or is handed off | `HANDOFF.md` whole, `ROADMAP.md` ticks and decisions, proposes the commit |
| `aegonex-done` | a milestone is finished | runs its checks, collapses it in `ROADMAP.md`, puts its documents in the proposed commit command for deletion |

Design and contracts: `docs/design.md`. How the skills are tested:
`docs/testing.md`.

## Install

```bash
npx skills add Aegonex/skills -g --all
```

One command, every skill, every agent the CLI detects on this machine
(Claude Code, Codex CLI, Cursor, OpenCode, GitHub Copilot CLI). Drop `-g`
to install into the current project instead of the user profile. Pick
skills with `-s aegonex-init,aegonex-exit`, or list them first with `--list`.

Update later with `npx skills update -g`.

### Development

Link the working copy so edits are live everywhere:

```bash
for s in init plan note exit done; do
  ln -s "$PWD/skills/aegonex-$s" ~/.agents/skills/aegonex-$s
  ln -s ../../.agents/skills/aegonex-$s ~/.claude/skills/aegonex-$s
done
```
