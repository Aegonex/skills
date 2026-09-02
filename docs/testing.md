# Testing a skill

Skills are tested like code: watch an agent fail without the skill, write
the skill against those failures, watch it pass, close the loopholes.

1. Build fixture repos with `tests/fixtures/make-fixtures.sh <dir>`
   (`stale-app`: state files whose HANDOFF drifted from git; `fresh-app`:
   no state files), then `make-exit-fixture.sh` and `make-noinit-fixture.sh`
   for end-of-session states. Copy a fixture per run; agents mutate them.
2. RED: give a cheap model (Sonnet) the fixture path and the user's message
   only. Record what it reads, runs, writes and replies.
3. GREEN: same runs, with "the user invoked <skill>; read SKILL.md and
   follow it". A judge agent verifies on disk (git status, file contents,
   grep for a planted secret) and scores a fixed rubric.
4. REFACTOR: every deviation becomes a red flag or a required slot in the
   template, then the affected scenarios run again.

Results that shaped v0.1: without the skills, agents opened source files
before the user said go, missed commits newer than the handoff, closed
sessions by committing on their own (3/3) and wrote fragments of a planted
secret into HANDOFF.md (2/3).
