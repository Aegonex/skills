---
name: aegonex-note
description: Use the moment something happens in a session that git cannot reconstruct — the user makes a decision (what and why), an approach that was tried is abandoned, or an environment fact is learned (a command needs a flag or a variable, a tool is missing). Also use when the user says "จดไว้", "จำไว้ว่า", "ทางนี้ไม่ได้ผล", "ตัดสินใจแล้วว่า", "note this", "remember that". Not for progress reports or anything a commit already shows.
license: MIT
metadata:
  author: Aegonex
  version: "0.3.0"
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

## Language

The reply and the text of the line are in the user's language: the language
of the message that holds the decision, dead end or fact; else the
language of the conversation so far. The kind word in the file stays English
(`decision`, `dead end`, `fact`), because `aegonex-exit` sorts by it; the
reply translates it (Thai: `ตัดสินใจ`, `ทางตัน`, `ข้อสังเกต`).

## Procedure

1. Compose one line:
   `- <HH:MM> <decision|dead end|fact>: <text>`
   at most 120 characters, paths allowed, no code, in the user's language
   for the text. A decision carries its why in the same line.
2. Scan the line before writing:
   `grep -nEi 'KEY|TOKEN|SECRET|PASSWORD|Bearer|sk-[A-Za-z0-9]|ghp_|xox[a-z]-|AKIA|[A-Za-z0-9_/+=-]{32,}'`
   A hit becomes `<redacted>`; the fact around it stays ("the shell exports
   the prod token by mistake; use JWT_SECRET=dev"). A prefix or suffix of a
   secret is a secret.
3. Append the line under `## Session log` at the end of `HANDOFF.md`:
   - the section exists: append the line after its last line;
   - the section is missing: append `\n## Session log\n` and the line;
   - `HANDOFF.md` is missing: create a shell containing only
     `# HANDOFF — <today>`, a blank line, `Branch: <git branch --show-current> · HEAD: <git rev-parse --short HEAD>`,
     a blank line, `## Session log`, and the line. Exit still owns the file
     and will overwrite it.
   Nothing else in the file changes: not Stopped at, not Next step, not a
   character above the section.
4. Reply with exactly one line, and continue whatever the user asked for:
   `Noted (<kind>): <text>` / `จดแล้ว (<ประเภท>): <text>`, without the time
   and the leading `- `. No question, no summary, no table. If the user's
   message also asked for work, the noted line comes first and the work
   follows in the same reply.
5. When the section now has twelve or more lines, add one more reply line:
   `Session log is long (<n> lines): run aegonex-exit when you stop.` /
   `บันทึกยาวแล้ว (<n> บรรทัด) ถ้าจะพักให้เรียก aegonex-exit`.

Reads: the tail of `HANDOFF.md`, `git branch --show-current`,
`git rev-parse --short HEAD`. Writes: one line. Never `ROADMAP.md`, never
`AGENTS.md`, never code, never another section of `HANDOFF.md`.

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

## Red flags — stop, you are leaving the procedure

- A `ROADMAP.md` edit in a message that is not `aegonex-plan`,
  `aegonex-exit` or `aegonex-done`.
- A reply that does not start with the noted line when a decision was just
  made.
- Two lines written for one fact.
- A question mark in the reply.

## Quick reference

| Situation | Note does |
|---|---|
| "ตัดสินใจแล้วว่า X เพราะ Y ทำต่อเลย" | writes `- HH:MM decision: X เพราะ Y`, replies `จดแล้ว (ตัดสินใจ): X เพราะ Y`, then the work |
| Approach A failed, switching to B | writes `- HH:MM dead end: A, <why>`, replies `Noted (dead end): A, <why>` before B starts |
| A test needed `JWT_SECRET=dev` | writes `- HH:MM fact: npm test needs JWT_SECRET=dev`, replies `Noted (fact): npm test needs JWT_SECRET=dev` |
| Text contains a token | the token becomes `<redacted>`, the fact stays |
| No `HANDOFF.md` yet | the shell is created with only the header and the log |
| Twelfth line | the `aegonex-exit` hint is added |
