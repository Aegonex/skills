# Scaffold: AGENTS.md and CLAUDE.md

Read this when step 2 of `aegonex-init` found `AGENTS.md` or `CLAUDE.md`
missing. Init creates only these two files, and only after the user answers
`go?`. `ROADMAP.md` belongs to `aegonex-plan`, `HANDOFF.md` to
`aegonex-exit`; init never creates either.

## Before the brief: derive, do not write

Read only manifests and top-level docs, never source:
- name: `package.json` name, `pyproject.toml` name, `go.mod` module,
  `Cargo.toml` name, else the directory name
- stack: languages, frameworks and runtimes named in those manifests
  (`package.json` dependencies, `pyproject`/`requirements`, `go.mod`,
  `Cargo.toml`, `Gemfile`, `composer.json`); runtime pins from `.nvmrc`,
  `.tool-versions`, `.python-version`
- commands: `package.json` scripts, `Makefile` targets, `justfile`,
  `taskfile`; keep the ones for dev, test, build, lint
- rules: anything explicit in `README.md` or `CONTRIBUTING.md`; otherwise a
  single `TODO(owner):` marker stays under Rules for the user to fill

Hold the derived content in memory. The brief's `Repo:` line ends with
`missing: <files>` and `First step:` starts with `create <files>, then …`.

## After go: write

- `AGENTS.md` from `assets/AGENTS.md` with the derived content filled in.
  `Scratch: docs/scratch/` stays as written unless the repo already has an
  obvious scratch directory; it is the only place a skill may propose
  deleting from.
- `CLAUDE.md`: if absent, copy `assets/CLAUDE.md`; if present, append the
  single line from `assets/CLAUDE.md` and change nothing else.

Then say `created: <files>` in one line. If `First step:` continued with
`run aegonex-plan`, name it and stop: the planning questions belong to that
skill.

Not part of scaffolding: `npm install` or any dependency install, creating
product code, committing, asking about goals or milestones.
