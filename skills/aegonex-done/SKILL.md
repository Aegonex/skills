---
name: aegonex-done
description: Use when the user wants a milestone or a task closed, merged and cleaned up — "ปิด M2", "close M2", "ปิด milestone", "milestone นี้เสร็จแล้ว", "close this task", "ปิด task นี้", "merge it", "ship it" — or when every step of the current milestone in ROADMAP.md is ticked and it is not closed yet, when a handoff names aegonex-done, or when the user says a pull request was merged ("PR merge แล้ว", "the pull request is merged"). Also use when the user asks to clean up documents a finished piece of work no longer needs.
license: MIT
metadata:
  author: Aegonex
  version: "0.5.1"
---

# aegonex-done

## Overview

This skill closes a unit of work, a milestone `m<n>` or a task `t-<slug>`, each in its own folder and
branch (the `Working mode` section of `AGENTS.md`); the last milestone closes the project the same way.

Core principle: **closed means proved, then landed, then removed.** Every `done when` is checked now;
only then is the milestone collapsed, its documents deleted, the branch landed on Base and its folder
and branch removed, all on one `go` after a brief that names each of them. It is the one verb that
runs checks; the user's word is not evidence for a check that can run.

## When to use

Closing, merging or shipping a milestone or a task; a milestone whose steps
are all ticked; a merged pull request. Not for: ending a session or landing
unfinished work (`aegonex-exit`), planning (`aegonex-plan`), ticking a step.

## Language

Every reply, its labels, question and options included (`go` stays `go`),
is in the language of the user's message; a message with no language of its own (only the skill's
name, or a bare answer such as `go`, `ok`, `yes`) takes that of the conversation so far, else of
`ROADMAP.md`, else English. Labels are given in English and Thai; translate the English for another
language. Command output is quoted as is.

## Procedure

The steps run in order, without commentary: the brief is the whole reply.
Every command, read-only ones included, is its own tool call on one line: no `&&`, `||` or `;`. Git is always
`git -C "<absolute folder>" ...`, reads included, even when the shell or a harness prefix already stands there;
never `cd` to run a read. A check, the tests and the install run in `<f>` as one chain, `cd "<f>" && <command>`,
one call, even where the shell stands, since a shell may not keep a `cd` between calls (PowerShell 5.1 has no `&&`:
`Set-Location "<f>"`, then the command); step 7.4's remove chains `cd "<main>"` the same way. An exit code is read
from the tool result (no error shown: 0), never with `; echo $?` or `|| true`. Status is read as
`git -C "<f>" -c core.quotePath=false status --short`, so paths go back to git as printed. The first numbered step
that fails ends the skill with the brief for a unit that cannot close; step 3 always finishes.

### 1. Find the unit

Step 1 runs whole and first on every call, a go or a message that a pull request was merged
included: its commands and stop lines run again; nothing is carried over from an earlier turn.

```bash
git -C "<here>" worktree list --porcelain   # first worktree path: <main>, branch lines: open units
date +%F                             # today, for `closed <date>` (PowerShell: Get-Date -Format yyyy-MM-dd)
```

`<here>` is the folder the session opened in (removed since: the shell's folder); `not a git repository` there: read `../aegonex-init/references/repos.md`
and follow it. `<Base>` and `<remote>` are the `Base:` and `Remote:` values in `<main>`'s
`AGENTS.md`. The unit `<u>` is the one the user named, else the one your
folder is on, else the only open unit; with several, one question names
them. `<f>` is the folder whose `branch` line is `refs/heads/aegonex/<u>`.
One line stops the skill when: there is no such folder (`<u> has no work
folder: run aegonex-init first`); `git -C "<main>" branch --list "aegonex/<u>--p*"`
prints a branch (`<u> has parts not integrated: <branches>`); `<f>` is under
`<main>/.worktrees` (or there is no remote) and `git -C "<main>" branch --show-current`
does not print `<Base>` (`the main folder is on <b>; by hand: git -C "<main>" switch <Base>`).
It is **closed** when `git -C "<f>" log -1 --first-parent --no-merges --format=%s`
prints `chore: close <u>`, and **online** when
`git -C "<f>" rev-parse --verify -q refs/remotes/<remote>/aegonex/<u>` prints the
hash `git -C "<f>" rev-parse aegonex/<u>` prints. The first match decides:
1. The user says its pull request was merged: step 8. Not closed, with no
   online copy (the `rev-parse --verify` above prints nothing): one line,
   `<u> is not closed; no pull request was opened for it` /
   `<u> ยังไม่ได้ปิด จึงยังไม่มี pull request`, then the routes below.
2. Closed and online: the waiting brief of step 8.
3. Closed, not online: when `git -C "<main>" merge-base --is-ancestor aegonex/<u> <remote>/<Base>`
   (no remote: `<Base>`) exits 0, it has landed: the brief offers **Clean up** only
   (`Will remove`). Otherwise step 2, then the brief with `Will land` in place of
   `Will commit` and the row `Pull request`: `if one was merged, say merged
   instead`; steps 3 to 5 are skipped.
4. Otherwise: steps 2 to 7.

For routes 3 and 4 the status of `<f>` must be empty. A modified or new
`HANDOFF.md` stops with `run aegonex-exit first: HANDOFF.md has notes not saved` /
`เรียก aegonex-exit ก่อน: HANDOFF.md มีบันทึกที่ยังไม่ได้เก็บ`. Other files (untracked
files under `Scratch:` excepted: they are deletion candidates) stop with the
cannot-close brief, no count, one row `Uncommitted | <files>` / `ยังไม่ได้ commit | <files>`
(no git command in a row), `**First step:** commit <files> into <u>`, then the question
`Commit them now?` / `commit เลยไหม?` (options `go`, `Not now` / `ไม่ใช่ตอนนี้`), or the last line
`Reply **go** to commit them, or tell me what to do instead.` / `พิมพ์ **go** เพื่อ commit หรือบอกว่าอยากทำอะไรแทน`.
Its go runs `git -C "<f>" add -- <files>` and `git -C "<f>" commit -m "wip: <u> before close" -- <files>`,
then this skill again. The checks prove exactly what lands.
With `## Repos (aegonex 0.5)` in `<main>`'s AGENTS.md, routes 3 and 4 also stop while the unit's ROADMAP line has `after: <r> <v>` or a
`t-<slug> after: <r> <v>` line names it (found as step 3 finds `done when:`) and the landed check of `../aegonex-init/references/repos.md`
fails: `<u> lands after <r> <v>, not landed yet: run aegonex-done for <r> <v> first` / `<u> ต้อง land หลัง <r> <v> ซึ่งยังไม่ land: เรียก aegonex-done ของ <r> <v> ก่อน`.

### 2. Sync with Base

In the unit folder, before any check; it commits only on `aegonex/<u>` and
needs no go:

```bash
git -C "<f>" fetch <remote> <Base>                     # no remote: skip it, a failure: go on
git -C "<f>" merge-base --is-ancestor <remote>/<Base> HEAD
git -C "<f>" merge --no-edit <remote>/<Base>           # only when the line above exits 1
```

then the same last two lines with `<Base>` (with no remote, only those),
but only when `git -C "<f>" log --format=%s <remote>/<Base>..<Base>`
(`<remote>/<Base>` missing: `<Base>`) prints nothing or only
`chore: aegonex setup` lines. Other lines are the user's commits that are
not online: the brief stops, `<main> has commits that are not online:
<subjects>`, and asks whether this unit lands without them (then `<Base>`
is skipped). A conflict: `HANDOFF.md` keeps this unit's copy
(`git -C "<f>" checkout --ours -- HANDOFF.md`), then gets the Dead ends,
Notes and Session log lines of `git -C "<f>" show MERGE_HEAD:HANDOFF.md`
that it lacks, under the same headings; another file is resolved keeping
both sides' intent; then `git -C "<f>" add -- <files>` and
`git -C "<f>" commit --no-edit`. A conflict you cannot resolve, or a merge
that refuses to start: `git -C "<f>" merge --abort` when
`git -C "<f>" rev-parse -q --verify MERGE_HEAD` prints a hash, and the first
step names the files.

### 3. Prove it

The checks: a milestone's `done when` and every step's `done when` in
`<f>/ROADMAP.md`; a task's from the session, else a `t-<slug> done when:` line
in the `HANDOFF.md` of the open milestone folder or of `<f>`. A task with none:
the first step is `name the check for t-<slug>`. Each distinct check runs once, in order, even
after one fails; a command that several `done when` lines name runs and counts once (`<n>` and
`<total>` below count distinct checks):
- a command or a test: run it in `<f>` (`cd "<f>" && <command>`), never in watch mode, with the environment the handoff's
  Notes name; pass or fail by its exit code and output. A failure with no output: its reason is the
  condition the check's own script tests, read from that script, else `exit <code>, no output`;
- a fact in a file (`recorded below`, meaning `ROADMAP.md`, or `documented in <file>`): read that
  file in `<f>`; it passes when the fact is there, else failed: `not in <file>`;
- a visible behaviour: ask the user for one word, or accept it if the user
  already stated it in this session.

Then the project's tests: the first `## Commands` line of `AGENTS.md` that
contains `test`, run once with `CI=true` (PowerShell `$env:CI='true'`) and the
environment the handoff's Notes name, as one check. It is skipped only when the line is missing or
still `<test command>`, when a check above is the same command line, or when
`git -C "<f>" diff --name-only <Base>` lists only `.md` files; otherwise it runs and counts as one
check, even when its script repeats checks above.

A runner or dependency that is missing (exit 127, `command not found`, `is
not recognized`, no dependency folder yet) is not a failure: its row reads
`not run: <runner> missing` / `ยังไม่ได้รัน: ไม่มี <runner>`, not counted as
passed. When nothing failed, the first step is the install command of `AGENTS.md`, on go,
or, when that line is `none`, missing or still `<install command>`, by hand with no go
for it: `install <runner> (e.g. npm install) and put the command on the install line of AGENTS.md`.
This skill never installs on its own. `Cannot find module` for a project path is a failure.

Then the anchor grep:

```bash
git -C "<f>" grep -n --untracked -E "AIDEV-(TODO|NOTE)" -- . ":(exclude,glob)**/AGENTS.md" ":(exclude,glob)**/CLAUDE.md" ":(exclude,glob)**/ROADMAP.md" ":(exclude,glob)**/HANDOFF.md"
```

An `AIDEV-TODO` naming this unit fails: tagged `(M<n>)` or `(t-<slug>)`, or
the name as a whole word in any case (`M2`, `m2`; not `M20`). The grep is
not a check in the count; each TODO naming this unit is a row.

When all of this has run, if anything failed or did not run: the brief lists
every failure and not-run row, TODO rows included; its first step is the
first failure's fix (none failed: the install), and nothing below happens.
The user insisting changes nothing; the failing command's output is the answer.

### 4. Retire (composed now, written on go)

A milestone collapses in `ROADMAP.md` to one line,
`- [x] M<n> — <name> · closed <date>`; its steps and `docs:` line go (git
keeps them). A decision goes only when nothing in the landed code still follows it (how this
milestone's own work was run, a spike's result); one the shipped behaviour embodies (a lifetime, a
limit, a format, a library) stays; when unsure, keep it. A `Not doing` entry goes only when it names
only this milestone. Nothing under a later milestone changes. A task
leaves `ROADMAP.md` as it is. `AIDEV-NOTE` comments are never touched.
`HANDOFF.md` is never touched or deleted, not even at project close.

### 5. Retrospective

From the unit's dead ends (`HANDOFF.md`, the session), the one that would
have saved the most time as a rule becomes one line under Rules in
`<f>/AGENTS.md` (never `<main>`'s), in the same commit, shown in the `New rule`
row; none generalises, no rule. No other skill writes `AGENTS.md` after setup.

### 6. The brief

Candidates for deletion are exactly: the paths on the closed milestone's
`docs:` line, and files under the `Scratch:` directory of `AGENTS.md`, in
`<f>`. Nothing else is ever a candidate. Tracked files are deleted with
`git -C "<f>" rm -- <files>`; untracked ones one file per line with `rm -- "<f>/<file>"` (PowerShell
`Remove-Item -LiteralPath "<f>\<file>"`), never `-r` or `-f`; git cannot restore those, so the
brief lists them apart.

Before the brief, the secret scan of what the push would send, with
`<range>` = `<remote>/<Base>..aegonex/<u>` (no remote: `<Base>..aegonex/<u>`;
when `git -C "<f>" rev-parse --verify -q <remote>/<Base>` prints nothing:
`aegonex/<u>`):

```bash
git -C "<f>" log -p -U0 --no-merges -G "<RE>" <range>
git -C "<f>" log --no-merges --diff-filter=A --name-only --format= <range>
```

`<RE>` is `sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[a-z]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY|://[^/:@ ]+:[^@ ]{3,}@`.
An added line matching it, an added `.env*` file other than
`.env.example`, or a scan command that exits non-zero stops the close: `a key is in <file> (commit <sha>)`, and
the first step is by hand: `git -C "<f>" reset --soft <remote>/<Base>`
(the files stay; the unit's commits become one), take the key out, commit.

`git -C "<f>" -c core.quotePath=false status --short --ignored` lines starting `!!` outside
`node_modules/`, `.venv/`, `venv/`, `dist/`, `build/`, `target/`, `vendor/`,
`__pycache__/`, `.next/`, `coverage/` are deleted with the folder; they are
named in the `Goes with the folder` row.

Print the brief as markdown, not inside a code block, so the table renders.
When every check passed and no TODO names the unit:

```
**<u> <name> can close.** All <n> checks passed

| Item | Detail |
|---|---|
| <row label> | <one fact, in words> |

**Will commit:** the deletions above, `ROADMAP.md` and `AGENTS.md`, with message `chore: close <u>`, then push it to `<Base>` (no remote: merge) and remove `.worktrees/<u>` and `aegonex/<u>`
```

Thai title: `**ปิด <u> <name> ได้** เช็กผ่านครบ <n>/<n>`; header
`| เรื่อง | รายละเอียด |`; action line `**จะ commit:** การลบข้างบน พร้อม
ROADMAP.md และ AGENTS.md ด้วยข้อความ chore: close <u> แล้ว push เข้า <Base>
และลบ .worktrees/<u> กับ aegonex/<u>` (paths and the message in backticks). Rows, in this
order, only when they have something to say:

| Row (English / ไทย) | Says | Appears when |
|---|---|---|
| ROADMAP / ROADMAP | `<M> collapsed to one line` / `ยุบ <M> เหลือบรรทัดเดียว`, plus the decisions and Not doing lines dropped, if any | a milestone |
| New rule in AGENTS.md / กฎใหม่ใน AGENTS.md | the retro rule | step 5 wrote one |
| Delete, restorable from git / ลบ (กู้คืนจาก git ได้) | the tracked candidates | there are any |
| Delete, not in git, cannot be restored / ลบ (ไม่อยู่ใน git กู้คืนไม่ได้) | the untracked candidates | there are any |
| Lands / ลงที่ | `pushed to <Base>` / `push เข้า <Base>`; no remote: `merged into <Base> here` / `merge เข้า <Base> ในเครื่อง`; a protected `<Base>` turns it into a pull request on go | always |
| Goes with the folder / ลบไปพร้อมโฟลเดอร์ | the ignored files named above, `.env` included | there are any |
| Next / ต่อไป | `` `aegonex-plan` for <next M>; type `/clear` first `` / `` `aegonex-plan` วางแผน <next M> แนะนำให้พิมพ์ `/clear` ก่อน ``; after a task, the next step of the open work; on project close `project closed` / `ปิดโปรเจกต์แล้ว` | always |

When anything failed or did not run (a TODO row included):

```
**<u> <name> cannot close yet.** <passed> of <total> checks passed

| Check | Result |
|---|---|
| <the command in backticks, or the behaviour or fact in words> | <failed: the reason from its output, else as step 3 says, in a few words; or not run: <runner> missing> |

**First step:** <the fix>
```

Thai: `**ยังปิด <u> ไม่ได้** เช็กผ่าน <passed>/<total>`, header `| เช็ก | ผล |`,
`ไม่ผ่าน: <reason>` / `ยังไม่ได้รัน: ไม่มี <runner>`, `**ขั้นแรก:**`. Rows: the failing checks,
then the not-run ones, then each open `AIDEV-TODO` naming the unit as a failing row
`TODO <file:line>`, outside the count. A passed check is only in the count, never a row (no
`passed` / `ผ่าน`). Nothing is written, deleted or landed.

Paths, commands and commit ids go in backticks. No emoji or icons. Not
shown: the HEAD sha, counts of collapsed steps or NOTEs, raw git commands.

The question comes last, once, and nothing follows it (none when the first step is by hand):
- With a multiple-choice question tool (Claude Code: `AskUserQuestion`):
  all passed: `Close, land and remove now?` / `ปิด push และลบโฟลเดอร์เลยไหม?`,
  options `Not yet` / `ยังไม่ปิด` first, then `go`; a check failed: `Start the fix?`
  / `เริ่มแก้เลยไหม?`, options `go` and `Not now` / `ไม่ใช่ตอนนี้`.
- Otherwise the reply ends with one line, alone, after a blank line. All
  passed: `Reply **go** to close, land and remove it, or tell me which
  files to keep.` / `พิมพ์ **go** เพื่อปิด push และลบ หรือบอกว่าอยากเก็บไฟล์ไหนไว้`.
  A check failed: `Reply **go** to start the fix, or tell me what to do
  instead.` / `พิมพ์ **go** เพื่อเริ่มแก้ หรือบอกว่าอยากทำอะไรแทน`.

### 7. On go

Nothing is deleted, committed (step 2's Sync aside) or landed before the answer. Any clear yes
is go (go, ok, yes, ได้, โอเค, ลุย); silence, a timeout or an autopilot
answer is not.

A go on a cannot-close brief (other than step 1's Uncommitted one) runs only its first step, as one part in `<f>` under
the Leader mode of `AGENTS.md`: **Review** reruns the check the fix is for and reads the status,
`git -C "<f>" diff HEAD` and every new file; a PASS is committed naming its files (**Integrate**). A fresh read-only
subagent reviews it, a one-line fix too, whenever you have a subagent tool; with no subagent tool, you review it
yourself before that commit. A first step that is the install command is just run. That go closes, lands and removes
nothing: after the first step and its commit (if any) the skill runs again from step 3, every check anew (the review's
too, never its result), and the reply is the new brief with one line under its title, no sha, in place of **Review**'s
`PASS:` or `FAIL:` line: after a committed fix `Fixed: <files> committed` / `แก้แล้ว: commit <files>`, after a FAIL
`FAIL: <evidence>`; a review of your own ends it with `(review not independent)`, never translated.

Otherwise the go runs, one command per line:
1. `git -C "<f>" rm -- <tracked candidates>`; each untracked candidate is removed as
   step 6 says; `<f>/ROADMAP.md` and `<f>/AGENTS.md` are written, nothing in `<main>`.
2. `git -C "<f>" add -- ROADMAP.md AGENTS.md` (those that changed), then
   `git -C "<f>" commit --allow-empty -m "chore: close <u>"`.
3. **Land** as the `Working mode` section of `AGENTS.md` says, then by the
   whole push output (the reason is often on `remote:` lines):
   - accepted: **Clean up**, below;
   - `[remote rejected]`, and `secret` anywhere: stop, `the host found a
     key in these commits` / `ฝั่ง host เจอ key ใน commit เหล่านี้`;
   - `[remote rejected]`, and `protected`, `GH006`, `GH013`, `pull request`
     or `review` anywhere: the pull-request path, step 7.3 of this skill's
     `references/pull-request.md` (read it now); the folder stays until the pull request is merged;
   - `[rejected]`: Base moved; the close stays; `Base moved: run aegonex-done
     again` / `Base ขยับแล้ว: เรียก aegonex-done อีกครั้ง`;
   - anything else: stop and quote its first `error:` or `fatal:` line.
4. **Clean up**, in order, each refusal stopping it with the files named:
   1. `git -C "<main>" merge-base --is-ancestor aegonex/<u> <remote>/<Base>`
      (no remote: `<Base>`) exits 0; step 8 replaces this check.
   2. **Update**: `git -C "<main>" branch --show-current` prints `<Base>`
      (else step 1's stop line), then `git -C "<main>" merge --ff-only <remote>/<Base>`
      (no remote: skip). Refused: `git -C "<main>" reset --keep <remote>/<Base>` only when
      `git -C "<main>" log --format=%s <remote>/<Base>..<Base>` prints one
      or more lines, all `chore: aegonex setup`, and
      `git -C "<main>" grep -q -F "## Working mode (aegonex 0.4)" <remote>/<Base> -- AGENTS.md`
      exits 0 (the setup is online), and the same for `## Repos (aegonex 0.5)` when `<main>`'s AGENTS.md has it;
      that one alone not online: go on to 3, with `-D` in 4 (the next unit opened from `<Base>` carries it); else
      stop, `<main> has commits that are not online: <subjects>`.
   3. `cd "<main>" && git -C "<main>" worktree remove "<f>"`, one call, even
      where the shell resets, so a shell that keeps its folder does not hold
      `<f>` (PowerShell 5.1: `Set-Location "<main>"`, then the remove). It
      refuses modified or untracked files; never add `--force`. A remove that
      fails part-way (a Windows file lock): `git -C "<main>" worktree prune`,
      and ask the user to delete the folder.
   4. `git -C "<main>" branch -d aegonex/<u>` (after step 8: `-D`). The
      online copy `<remote>/aegonex/<u>` is never deleted.
   In a folder your harness made: skip 2 and 3, run
   `git -C "<f>" switch --detach`, then 4 with `-C "<f>"`; the folder and
   the harness's own branch stay, and `aegonex-init` updates `<main>`.

The reply after go is exactly two lines of plain text, no outer code span and no question; only the sha, branch
names, paths, skill names and commands are in backticks. Line 1: `` `a1b2c3d` · landed on `main` · `.worktrees/m2` removed `` /
`` `a1b2c3d` · push เข้า `main` แล้ว · ลบ `.worktrees/m2` แล้ว `` (no remote: `merge` for `push`); on the pull-request
path, with step 6's ignored files after the folder: `` `a1b2c3d` · pull request <link> · `.worktrees/m2` kept until it merges (with `.env`) `` /
`` `a1b2c3d` · pull request <link> · เก็บ `.worktrees/m2` ไว้จนกว่าจะ merge (พร้อม `.env`) ``. Line 2: `Next:` / `ต่อไป:` and
the brief's `Next` row, e.g. `` Next: `aegonex-plan` for M3; type `/clear` first `` / `` ต่อไป: `aegonex-plan` วางแผน M3 แนะนำให้พิมพ์ `/clear` ก่อน ``.

### 8. After a pull request

Read this skill's `references/pull-request.md` and follow its step 8: the waiting brief (closed,
online, the user has not said it is merged), and the compare and **Clean up** once the user says it is merged.

## Never close on a word

| Excuse | Reality |
|---|---|
| "The user said it is done, ticking is a formality" | The user's word covers behaviours they saw, not commands that can run. Run them. |
| "The failing check is flaky, the code is fine" | A flaky check is a failing check. |
| "I'll install the dependencies so the check can run" | The install is its own first step, on go, or by hand when `AGENTS.md` names none. |
| "I'll also clean up docs/ or scratch now" | Only the `docs:` line and `Scratch:`, only on the go. |
| "The folder has one stray file, `--force` is fine" | Removal refuses it on purpose; name the file and stop. |
| "The pull request is surely merged" | The user says so, and the branch equals its online copy or, that copy gone, is in `<remote>/<Base>`. |

## Red flags — stop, you are leaving the procedure

- `rm`, git's `rm` or `commit` (step 2's Sync aside), `push` or `worktree remove` before the go.
- A `[x]` written before the check ran.
- `HANDOFF.md` opened for writing or listed for deletion.
- A file written, checked out or restored in `<main>`: the retro rule and `ROADMAP.md` go in `<f>`.
- A delete-row path on neither the `docs:` line nor under `Scratch:`.
- `--force`, `push --delete`, `reset --hard`, or `branch -D` without step 8's
  checks.
- A git command without `-C "<folder>"`, a chain other than `cd "<f>" && <command>` or step 7.4's remove, or a check or a remove run on the call after a bare `cd`, after the go too.

## Quick reference

| Situation | Done does |
|---|---|
| All checks pass | sync, collapse, retro, delete rows, one question; go closes, lands, removes |
| One check fails | every check still runs; the table lists each failure, nothing written; go runs only the first step, reviewed, then the checks again |
| Push refused as protected | branch pushed, pull request opened, folder kept until "it is merged" |
| "The pull request is merged" | step 1 again, the compare; closed: **Clean up** at once with `-D`, no second question; not closed: Remove / Keep, Keep first |
| Harness-made folder | lands from it, detaches, deletes `aegonex/<u>`, keeps the folder |
