# Scaffold: creating the three files

Read this only when step 2 of `aegonex-init` found none, or only some, of
`AGENTS.md`, `ROADMAP.md`, `HANDOFF.md` at the project root.

## Fresh project (none of the three)

1. Derive what the repo already knows. Read only manifests, never source:
   - name: `package.json` name, `pyproject.toml` name, `go.mod` module,
     `Cargo.toml` name, else the directory name
   - stack: languages, frameworks and runtimes named in those manifests
     (`package.json` dependencies, `pyproject`/`requirements`, `go.mod`,
     `Cargo.toml`, `Gemfile`, `composer.json`); runtime pins from
     `.nvmrc`, `.tool-versions`, `.python-version`
   - commands: `package.json` scripts, `Makefile` targets, `justfile`,
     `taskfile`; keep the ones for dev, test, build, lint
   - rules: anything explicit in `README.md` or `CONTRIBUTING.md`
2. Write the four files now, from the templates in `assets/`, with the
   derived content filled in and `TODO(owner):` markers where nothing was
   derivable. Do not wait for answers to write the skeleton.
   - `AGENTS.md` from `assets/AGENTS.md`
   - `ROADMAP.md` from `assets/ROADMAP.md`
   - `HANDOFF.md` from `assets/HANDOFF.md`, dated today, `Branch:` and
     `HEAD:` from git, body "Fresh start — nothing in flight."
   - `CLAUDE.md`: if absent, copy `assets/CLAUDE.md`; if present, append the
     single line from `assets/CLAUDE.md` and change nothing else
3. Continue `aegonex-init` at step 3 (anchors) and step 4 (drift, which is
   `none` on a fresh project), then print the brief of step 5 in its six-line
   shape: 📍 ends with `created: AGENTS.md ROADMAP.md HANDOFF.md CLAUDE.md`,
   🔁 reads `HANDOFF: fresh start`, ▶️ reads `answer the three questions
   below, then start M1 — go?`.
4. Directly under the brief, ask the three scaffold questions, all in one
   message, and only these:
   1. Goal in one sentence — what is this project for?
   2. The first milestone — what does "M1 done" look like?
   3. One rule I must never break in this repo (or "none").
   Then the closing line that names `aegonex-exit`.
5. When the answers arrive, fill `ROADMAP.md` (goal, M1) and `AGENTS.md`
   (rules) and remove the `TODO(owner):` markers they resolve. That is the
   go: work on M1's first step begins.

Not part of scaffolding: `npm install` or any dependency install, creating
product code, committing. Listing the created files in the brief's 📍 line
(`created: AGENTS.md ROADMAP.md HANDOFF.md CLAUDE.md`) is.

## Partial (some of the three exist)

Create only the missing files from `assets/`, deriving content the same way.
Keep every existing file untouched. Mention the created files in the brief's
📍 line. Ask the scaffold questions only for the file that needs them
(`ROADMAP.md` → questions 1–2, `AGENTS.md` → question 3).
