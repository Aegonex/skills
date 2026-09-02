# Aegonex skills

Personal, cross-agent skills. One canonical copy per skill, written to the
[Agent Skills](https://agentskills.io) spec, so the same `SKILL.md` works in
Claude Code, Codex CLI, Cursor, OpenCode and GitHub Copilot CLI.

This repository contains instructions and empty templates only. Project state
(ROADMAP.md, HANDOFF.md) lives in each project's own repository, never here.

## Skills

| Skill | Use when |
|---|---|
| `aegonex-init` | starting a work session on a project (first time or every day) |
| `aegonex-exit` | closing a work session: reconcile ROADMAP.md, rewrite HANDOFF.md, leave the entry point for the next session |

## Install

```bash
# one machine, all detected agents
npx skills add Aegonex/skills@aegonex-init -g

# development: link the working copy so edits are live everywhere
ln -s "$PWD/skills/aegonex-init" ~/.agents/skills/aegonex-init
ln -s ../../.agents/skills/aegonex-init ~/.claude/skills/aegonex-init
```
