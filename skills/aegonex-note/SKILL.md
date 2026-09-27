---
name: aegonex-note
description: Use the moment something happens in a session that git cannot reconstruct — the user makes a decision (what and why), an approach that was tried is abandoned, or an environment fact is learned (a command needs a flag or a variable, a tool is missing). Also use when the user says "จดไว้", "จำไว้ว่า", "ทางนี้ไม่ได้ผล", "ตัดสินใจแล้วว่า", "note this", "remember that". Not for progress reports or anything a commit already shows.
license: MIT
metadata:
  author: Aegonex
  version: "0.4.1"
---

# aegonex-note

## Overview

Everything else is written at `aegonex-exit`. A session cut by a quota, a
crash or an automatic compaction never reaches exit, and what it decided
and tried is gone. This skill writes the three facts git cannot
reconstruct the moment they happen: one line, appended to `HANDOFF.md`,
no question asked, and the work continues.

Core principle: **a note that waits is as fragile as exit.** The write is
one line and git keeps it; asking first defeats the purpose.

## When to use

Two triggers, both first-class:
- **The agent notices** one of three things, in any message of the
  session, whether or not the user names this skill:
  - a decision: the user chose something, with a reason ("ใช้ 60s ไม่ต้อง
    configurable", "we'll keep jose");
  - a dead end: an approach was tried and abandoned, with why;
  - an environment fact: a command needs a flag or a variable, a tool is
    missing, a test needs a setup step.
- **The user says** "จดไว้", "จำไว้ว่า", "ทางนี้ไม่ได้ผล", "ตัดสินใจแล้วว่า",
  "note this", "remember that".

Not for: progress ("started X", "finished Y"), anything a commit or a diff
already shows, plans (`aegonex-plan`), or the end of the session
(`aegonex-exit`). A decision inside the user's instruction to do work
("use 60s, then continue") is still a decision: note it, then do the work.
When a task `t-<slug>` starts, its done-when is noted as a fact:
`t-<slug> done when: <the test, route or output that proves it>`.

## Language

The reply and the text of the line are in the user's language: the language of the message that
holds the decision, dead end or fact; a message with no language of its own (only the skill's name,
or a bare answer such as `go`, `ok`, `yes`) takes the language of the conversation so far; else that
of `HANDOFF.md`; else English. The kind word in the file stays English (`decision`, `dead end`,
`fact`), because `aegonex-exit` sorts by it; the reply translates it (Thai: `ตัดสินใจ`, `ทางตัน`, `ข้อสังเกต`).

## Procedure

1. Read the clock once: `date '+%F %H:%M'` (PowerShell: `Get-Date -Format 'yyyy-MM-dd HH:mm'`);
   the stamp comes from that read, never from an example, a commit or the HANDOFF header. Compose
   one line: `- <YYYY-MM-DD HH:MM> <decision|dead end|fact>: <text>`, at most 120 characters judged
   by eye (never run a tool to count), paths allowed, no code, the text in the user's language.
   A decision carries its why in the same line only when the user or the session gave one; never an
   invented why. To fit, cut first the words that repeat the kind (a dead end needs no
   `didn't work`, `failed`, `ไม่เวิร์ค`, `ไม่ได้ผล`), then shorten the why; never cut a word that
   names what was tried or decided, and keep the user's own words for it.
2. Secret rule, applied as you compose, then checked after step 4 with
   `git -C "<folder>" grep -n -i -E --untracked 'KEY|TOKEN|SECRET|PASSWORD|Bearer|sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}' -- HANDOFF.md`;
   a hit on the new line that the rule replaces is fixed in place. The grep
   only finds candidates:
   - Kept: a variable or setting name (`JWT_SECRET`), an ordinary word
     (`refresh token`), a path, and a value that is an obvious placeholder
     (`dev`, `test`, `example`, `changeme`, `localhost`).
   - Replaced whole with `<redacted>`: any other value after a `KEY`,
     `TOKEN`, `SECRET` or `PASSWORD` name, a password inside a URL
     (`user:<redacted>@host`), and any key-shaped string. A prefix or
     suffix of a secret is a secret.
3. Find the folder: `git -C "<current folder>" worktree list --porcelain`; a unit folder has a
   `branch refs/heads/aegonex/…` line. Every command is its own tool call on one line (no `&&`, `||`, `;`;
   exit codes from the tool result). Run each git command of this skill exactly as written, with `-C` and
   the absolute folder, even when the shell already stands there; never `cd` (into the milestone folder or
   anywhere) to run one. The line goes into `HANDOFF.md` of the `aegonex/m<n>` folder that is not closed
   (`git -C "<f>" log -1 --first-parent --no-merges --format=%s` is not `chore: close m<n>`); with none,
   of the unit folder you work in. Noted from a `t-<slug>` folder into the milestone folder, the text
   starts with `t-<slug>: `. With no unit folder at all, write nothing and reply
   `Not saved (no work folder is open): <text>` / `ยังไม่ได้บันทึก (ยังไม่มีโฟลเดอร์งาน): <text>`.
4. Append the line under `## Session log` at the end of that `HANDOFF.md`,
   with the file tool in UTF-8, never through `echo` or `printf`:
   - the section exists: append the line after its last line;
   - the section is missing: append `\n## Session log\n` and the line;
   - `HANDOFF.md` is missing: create a shell containing only `# HANDOFF — <today>`, a blank line,
     `Branch: <git -C "<folder>" branch --show-current> · HEAD: <git -C "<folder>" rev-parse --short HEAD>`,
     a blank line, `## Session log`, and the line. Exit still owns the file and will overwrite it.
   Nothing else in the file changes: not Stopped at, not Next step, not a
   character above the section. Nothing is committed.
5. Reply with exactly one line, and continue whatever the user asked for: `Noted (<kind>): <text>` /
   `จดแล้ว (<ประเภท>): <text>`, without the stamp and the leading `- `. No question, no summary, no
   table. If the user's message also asked for work, the noted line comes first and the work follows
   in the same reply.
6. When the section now has twelve or more lines, add one more reply line:
   `Session log is long (<n> lines): run aegonex-exit when you stop.` /
   `บันทึกยาวแล้ว (<n> บรรทัด) ถ้าจะพักให้เรียก aegonex-exit`.

Writes: one line. Never `ROADMAP.md`, never `AGENTS.md`, never code, never another section of
`HANDOFF.md`, never a commit.

What the other skills do with the log: `aegonex-exit` folds each line into
Decisions, Dead ends or Notes for the next session and drops the section;
`aegonex-init` reads a surviving section as proof that the last session
ended without exit.

## Never

| Excuse | Reality |
|---|---|
| "I'll record it in ROADMAP's Decisions, that is where decisions live" | Plan and exit write ROADMAP. A note is one line in HANDOFF; exit moves it. |
| "I'll ask whether they want it noted" | The line costs nothing and git keeps it. Asking is the failure the skill exists to prevent. |
| "I'll note it at exit with everything else" | Exit may never run. Now. |
| "It is obvious from the code" | The why is never in the code. |
| "I'll tidy the rest of HANDOFF while I'm there" | One line, one section. |
| "The task folder has its own HANDOFF.md, I'll write there" | While a milestone folder is open and not closed, its HANDOFF.md is the only one. |

## Red flags — stop, you are leaving the procedure

- A `ROADMAP.md` edit in a message that is not `aegonex-plan`,
  `aegonex-exit` or `aegonex-done`.
- A reply that does not start with the noted line when a decision was just
  made.
- Two lines written for one fact.
- A question mark in the reply.
- `echo ... >> HANDOFF.md`, a `HANDOFF.md` in the main folder, a `cd`, `&&` `||` `;` in a command, or git without `-C "<folder>"`.

## Quick reference

| Situation | Note does |
|---|---|
| "ตัดสินใจแล้วว่า X เพราะ Y ทำต่อเลย" | writes `- <stamp> decision: X เพราะ Y`, replies `จดแล้ว (ตัดสินใจ): X เพราะ Y`, then the work |
| Approach A failed, switching to B | writes `- <stamp> dead end: A, <why>`, replies `Noted (dead end): A, <why>` before B starts |
| A test needed `JWT_SECRET=dev` | `dev` is a placeholder and stays: `Noted (fact): npm test needs JWT_SECRET=dev` |
| `DB_PASSWORD=Summer2026` in the text | the value becomes `<redacted>`, the name stays |
| Working in `t-login` while `m2` is open, not closed | the line goes to `.worktrees/m2/HANDOFF.md`, starting `t-login: ` |
| No work folder open | `Not saved (no work folder is open): <text>` |
