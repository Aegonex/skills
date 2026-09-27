# <project name>

## Stack
<languages, frameworks, runtime versions>

## Commands
- `<install command>` — install (run in each new folder)
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
- Start every session with `aegonex-init`: it opens the unit folder, and all work happens there. Plan a
  milestone with `aegonex-plan`; write decisions, dead ends and environment facts with `aegonex-note` the
  moment they happen; end the session with `aegonex-exit`; close, land and clean up a unit with `aegonex-done`.
- Without those skills: read `HANDOFF.md`, then `ROADMAP.md` (in the open milestone folder), check
  `git -C "<folder>" status --short`, report drift, and propose one first step before touching code.
- `HANDOFF.md` is at most one page and is rewritten, never appended.
- Anchor comments in code: `AIDEV-TODO(M<n>):` or `AIDEV-TODO(t-<slug>):` marks pending work of that
  unit at that spot, `AIDEV-NOTE:` marks an invariant. Delete a TODO when the work is done.
- git is the truth, these files are testimony: report contradictions.
- No secrets in any of these files.

## Working mode (aegonex 0.4)
Base: <base branch> · Remote: <remote name, or none>
- **Unit:** every change, even a one-line fix, is a unit `<u>`: `m<n>` for milestone M<n>, else `t-<slug>` (1-3 English
  words, `a-z0-9-`), in its folder `<f>`, `<main>/.worktrees/<u>`, on branch `aegonex/<u>`. `<main>`, the first `worktree `
  path of `git -C "<folder>" worktree list --porcelain`, stays on Base; only aegonex setup writes there. A harness-made
  worktree, detached or on a branch outside `aegonex/*`, is adopted as `<f>`: `git -C "<f>" switch -c aegonex/<u> <Base>`.
- **Commands:** one per tool call and line, reads too; no `&&` `||` `;`, `; echo $?` or `|| true` (exit code from the tool
  result, no error shown = 0); all git as `git -C "<folder>"`, even when the shell is there, after a go too; absolute paths.
- **Open** `<u>`: `git -C "<main>" worktree prune`; `git -C "<main>" worktree add "<f>" aegonex/<u>` (no such branch:
  `git -C "<main>" worktree add -b aegonex/<u> "<f>" <Base>`); `<main>/.worktrees/.gitignore` needs `*`; `cd "<f>"`; the
  install command (`none`: skip; fails: quote its first error line, go on; no retry, diagnosis, non-project command, `sudo`).
- **State files:** ROADMAP.md and HANDOFF.md change only in the open `m<n>` folder that is not closed (its last own commit is
  not `chore: close m<n>`). A task never edits ROADMAP.md, and HANDOFF.md only when no such folder is open.
- **Go:** landing, pushing, a pull request or removing a unit folder or branch needs a go to a reply naming it; silence, a
  timeout, autopilot or a go to another reply is no. A land go runs Clean up, then ≤3 plain lines, no question or table:
  `<sha> · landed on <Base> · .worktrees/<u> removed` + `Next: <next step>`. A task due to Land ends its report with the
  land question `Land? push to <Base>, remove .worktrees/<u>, aegonex/<u>: Not yet / go` (Thai `ยังไม่ land`),
  or, while `<f>`'s status lists HANDOFF.md, `run aegonex-exit first: HANDOFF.md has notes not saved`.
- **Land** when all the unit's work is done (a task: last part integrated): `git -C "<f>" push <remote> aegonex/<u>:<Base>`
  (no remote: `git -C "<main>" merge --ff-only aegonex/<u>`). Refused as protected: `git -C "<f>" push <remote> aegonex/<u>`
  (refused: stop, quote it); a pull request: `gh pr create` if the remote is a host URL (never guess a repo); keep `<f>`.
- **Clean up** only if `git -C "<main>" merge-base --is-ancestor aegonex/<u> <remote>/<Base>` exits 0 (no remote: `<Base>`)
  or aegonex-done step 8 finds it merged; `cd "<main>"`; `git -C "<main>" branch --show-current` prints `<Base>` (no-remote
  Land too); `git -C "<main>" merge --ff-only <remote>/<Base>` (no remote: skip); `git -C "<main>" worktree remove "<f>"`;
  `git -C "<main>" branch -d aegonex/<u>` (step 8: `-D`). Harness `<f>`: `git -C "<f>" switch --detach`, `branch -d` only.
- **Never** `--force`, `--no-verify`, `reset --hard`, `stash`, `add -A`; never remove uncommitted work, your own included, or
  unpushed work, or delete an online branch; work outside the request is named in the reply, not undone.
## Leader mode (aegonex 0.4)
Lead every file-changing request; given a part, do only it, in its folder. Reply in the user's language (`go` stays `go`).
1. **Size** by files, never by subagent tools: 2+ modules is 2-5 parts on different files, else one part in `<f>`; every part
   has a done-when, a command or fact showing it works. A request is one ROADMAP step or task: once its last part is
   integrated, report and stop until the user writes. What aegonex skills write (state files, setup, anchors) gets no review.
2. **Part folders** (with subagents; none: part by part in `<f>`: edit, **Review**, commit on PASS before the next): commit
   `<f>` first, naming each file; per part `git -C "<f>" worktree add -b aegonex/<u>--p<k> "<p>" aegonex/<u>` and install;
   `<p>`: `<root>/.worktrees/<u>--p<k>`, `<root>`: `<f>` if harness-made, else `<main>` (`*` in its `.worktrees/.gitignore`).
3. **Dispatch** one writer subagent per part, all at once, with a standalone prompt: folder, files, done-when, install
   command, and "Work only in <folder>, git as git -C "<folder>", commit there; never merge, push, delete or ask the user."
4. **Review** every part, a one-line fix too: a fresh read-only subagent, not its writer (none: you), runs the done-when and
   reads `git -C "<p>" diff aegonex/<u>...HEAD` (`<f>`: `git -C "<f>" status --short`, `git -C "<f>" diff HEAD`, new files).
   Reply per part: `PASS: <done-when>, diff: <files>` / `FAIL: <why>` (unsure: FAIL); by you: end `(review not independent)`.
5. **Integrate** only a PASS: `git -C "<f>" merge --no-ff --no-edit aegonex/<u>--p<k>` (conflict: `merge --abort`, FAIL),
   `git -C "<f>" worktree remove "<p>"`, `git -C "<f>" branch -d aegonex/<u>--p<k>`; `<f>` work: commit it naming its files;
   no go needed. One redo per FAIL, prompt starting `git -C "<p>" merge --no-edit aegonex/<u>`; a second FAIL: ask the user.
