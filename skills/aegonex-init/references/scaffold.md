# Scaffold: setup and move

Read this when `aegonex-init`'s brief names setup (`AGENTS.md`, `CLAUDE.md`
or the two sections missing) or a `Will move` row. Before go, derive only;
after go, write. Every command, read-only ones included, is its own tool call
on one line, with no `&&`, `||` or `;`; its exit code comes from the tool
result, never `; echo $?` or `|| true`. Git is always `git -C "<absolute folder>"`, even where the shell already
stands; the one chain is move step 9's install. Files are written with the file tool in UTF-8.

## Before the brief: derive, do not write

Read only manifests and top-level docs, never source:
- name: `package.json` name, `pyproject.toml` name, `go.mod` module,
  `Cargo.toml` name, else the directory name
- stack: languages, frameworks and runtimes named in those manifests;
  runtime pins from `.nvmrc`, `.tool-versions`, `.python-version`
- commands: `package.json` scripts, `Makefile` targets, `justfile`,
  `taskfile`; keep the ones for dev, test, build, lint
- install, when `AGENTS.md` has no install line, from the first of these that
  `<main>` has, in this order: `pnpm-lock.yaml` → `pnpm install`; `yarn.lock` → `yarn install`;
  `package-lock.json` or `package.json` → `npm install`; `uv.lock` →
  `uv sync`; `pyproject.toml` → `pip install -e .`; `requirements.txt` →
  `pip install -r requirements.txt`; `Gemfile` → `bundle install`; `go.mod` →
  `go mod download`; `Cargo.toml` → `cargo fetch`; else `none`
- rules: anything explicit in `README.md` or `CONTRIBUTING.md`; otherwise a
  single `TODO(owner):` marker stays under Rules for the user to fill
- Remote: the name `git -C "<main>" remote` prints when there is one;
  `origin` when there are several and it is listed; several without
  `origin`: ask (`aegonex-init` step 5); no remote at all: `none`
- Base: `git -C "<main>" symbolic-ref --short refs/remotes/<remote>/HEAD`
  without the `<remote>/` prefix; else `main` when
  `git -C "<main>" rev-parse --verify -q refs/heads/main` prints a sha; else
  `master` likewise; else ask (`aegonex-init` step 5); never the current branch

## After go: setup

In `<main>`, on `<Base>`. Moving from a branch `<b>`: `AGENTS.md` and
`CLAUDE.md` start from `<b>`'s copies when `<b>` has them:
`git -C "<main>" checkout <b> -- <file>`.
- `AGENTS.md` missing: write it from `assets/AGENTS.md`, filled in. Present without
  `## Working mode (aegonex 0.4)`: append everything from that heading to the end of `assets/AGENTS.md`, filled in,
  and add the install line under `## Commands` when it has none; nothing else changes. Under a parent folder
  (`references/repos.md`), then append `assets/AGENTS-repos.md` when its heading is missing, a new file too.
- `CLAUDE.md` missing: copy `assets/CLAUDE.md`. Present without
  `@AGENTS.md`: add that line at its top.
- `<main>/.worktrees/.gitignore` holding `*`, when missing. A `.dockerignore` that exists gets the
  line `.worktrees` (one call each: `ls -a "<main>"`, then, if it lists `.worktrees`, `ls -a "<main>/.worktrees"`).
- `git -C "<main>" add -- <files>` and `git -C "<main>" commit -m "chore: aegonex setup" -- <files>`, where
  `<files>` are `AGENTS.md`, `CLAUDE.md` and `.dockerignore` when they changed, the user's own edits to them
  included; never `.worktrees/.gitignore`, which ignores itself (git refusing it: leave it out, never `add -f`).
- No commit yet (`git -C "<main>" rev-parse --verify -q HEAD` prints
  nothing): `<files>` also name every top-level entry
  `git -C "<main>" -c core.quotePath=false status --short` lists, except `.env*`, dependency and
  build folders, and files that look like keys; the brief lists them.

Not part of setup: installing dependencies, product code, planning.

## After go: move

`<files>` are the paths `git -C "<main>" -c core.quotePath=false status --short`
lists (a rename `R a -> b` gives both paths), never `.env*`. `<b>` is
`<main>`'s branch when it is not `<Base>`; when `<main>` is detached, `<b>`
is the sha `git -C "<main>" rev-parse HEAD` prints. `aegonex-init`'s go
runs steps 1 to 5, then its update and setup, then 7 to 10.
1. `<main>/.worktrees/.gitignore`, as in setup.
2. `git -C "<main>" add -N -- <untracked files>` (when there are any).
3. `git -C "<main>" diff --binary HEAD --output="<main>/.worktrees/move.patch" -- <files>`
4. `git -C "<main>" restore --source=HEAD --staged --worktree -- <files>`
5. With a `<b>`: `git -C "<main>" switch <Base>`. `<b>` is kept.
6. (update and setup, in `aegonex-init`'s go)
7. Open the unit the changes go to: `git -C "<main>" worktree prune`; for a new
   unit, `git -C "<main>" worktree add -b aegonex/<u> "<main>/.worktrees/<u>" <b>`
   (no `<b>`: `<Base>` in its place; `aegonex/<u>` exists, `<b>` or a leftover:
   `git -C "<main>" worktree add "<main>/.worktrees/<u>" aegonex/<u>`), then,
   unless it was made from `<Base>`, `git -C "<unit folder>" merge --no-edit <Base>`,
   so the unit carries the setup commit and the v0.4 sections (a conflict:
   `git -C "<unit folder>" merge --abort`, the reply names it, go on). A unit
   whose folder exists gets `git -C "<unit folder>" merge --no-edit <b>` (with
   a `<b>`). Either merge runs before step 8.
8. `git -C "<unit folder>" apply --3way "<main>/.worktrees/move.patch"`. A
   conflict leaves both sides in the file; the reply names it. Then
   `git -C "<unit folder>" restore --staged -- <files>`, leaving out
   conflicted ones, so the changes arrive as they were: new files
   untracked, changes unstaged.
9. Install, only when step 7 added the folder (**Open** in `AGENTS.md`), once, as one call, since a shell may not
   keep a `cd` between calls: `cd "<unit folder>" && <install command>` (`none`: skip; PowerShell 5.1 has no `&&`:
   `Set-Location "<unit folder>"`, then the command); a failure: quote its first error line, no retry, go on.
10. `rm "<main>/.worktrees/move.patch"` (PowerShell: `Remove-Item -LiteralPath "<main>\.worktrees\move.patch"`).
The moved changes stay uncommitted in the unit folder.
