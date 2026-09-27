#!/bin/bash
# usage: make-v04-fixture.sh <v0.3 fixture dir> <unit> [--protected]
# Turns a built v0.3 fixture into a v0.4 one in place, using the spec's own recipes
# (references/scaffold.md: move, setup; AGENTS.md Working mode: Open):
# a bare origin next to it, setup committed on main, the fixture's branch and dirty files moved into .worktrees/<unit>.
set -e; a="${1:-}"; u="${2:-}"; SK=$(cd "$(dirname "$0")/../../skills" && pwd)
# Only a built fixture: a repo of its own (not a folder inside another repo) with no remote yet.
{ [ -n "$a" ] && [ -n "$u" ] && [ -d "$a/.git" ] && [ -z "$(git -C "$a" remote)" ]; } \
  || { echo "usage: make-v04-fixture.sh <v0.3 fixture dir> <unit> [--protected] (a fixture repo with no remote)" >&2; exit 1; }
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
o="$a.origin.git"; rm -rf "$o"; git init -q --bare -b main "$o"
git -C "$a" remote add origin "$o"; git -C "$a" push -q origin main; git -C "$a" fetch -q origin; git -C "$a" remote set-head origin main
b=$(git -C "$a" branch --show-current)
mkdir -p "$a/.worktrees"; printf '*\n' > "$a/.worktrees/.gitignore"
files=$(git -C "$a" status --porcelain | cut -c4-)
untracked=$(git -C "$a" status --porcelain | sed -n 's/^?? //p')
[ -n "$untracked" ] && git -C "$a" add -N -- $untracked
[ -n "$files" ] && git -C "$a" diff --binary HEAD --output="$a/.worktrees/move.patch" -- $files
[ -n "$files" ] && git -C "$a" restore --source=HEAD --staged --worktree -- $files
[ "$b" != main ] && git -C "$a" switch -q main
# setup: AGENTS.md and CLAUDE.md start from <b>'s copies (scaffold.md), then the two sections are appended
for f in AGENTS.md CLAUDE.md; do [ "$b" != main ] && git -C "$a" cat-file -e "$b:$f" 2>/dev/null && git -C "$a" checkout "$b" -- "$f"; done
touch "$a/AGENTS.md" "$a/CLAUDE.md"
# setup: append the two sections (and the install line) to AGENTS.md, @AGENTS.md to CLAUDE.md
grep -q '^## Commands' "$a/AGENTS.md" || printf '\n## Commands\n' >> "$a/AGENTS.md"   # a project without one gets the section, so install is known
perl -0pi -e 's/(## Commands\n)/$1- `none` — install (run in each new folder)\n/' "$a/AGENTS.md"
printf '\n' >> "$a/AGENTS.md"; sed -n '/^## Working mode (aegonex 0.4)/,$p' "$SK/aegonex-init/assets/AGENTS.md" \
  | sed 's/^Base: .*/Base: main · Remote: origin/' >> "$a/AGENTS.md"
{ printf '@AGENTS.md\n\n'; cat "$a/CLAUDE.md"; } > "$a/CLAUDE.md.new"; mv "$a/CLAUDE.md.new" "$a/CLAUDE.md"
git -C "$a" add -- AGENTS.md CLAUDE.md
git -C "$a" commit -q -m "chore: aegonex setup" -- AGENTS.md CLAUDE.md
[ "${3:-}" = --protected ] && { printf '#!/bin/sh\nwhile read o n ref; do [ "$ref" = refs/heads/main ] && [ -z "$ALLOW" ] && { echo "protected branch hook: changes must be made through a pull request"; exit 1; }; done; exit 0\n' > "$o/hooks/pre-receive"; chmod +x "$o/hooks/pre-receive"; }
start=main; [ "$b" != main ] && start="$b"
git -C "$a" worktree add -q -b "aegonex/$u" "$a/.worktrees/$u" "$start"
# a unit not made from Base merges it, so it carries the setup commit (scaffold.md, move step 7)
[ "$start" != main ] && git -C "$a/.worktrees/$u" merge -q --no-edit main
[ -f "$a/.worktrees/move.patch" ] && git -C "$a/.worktrees/$u" apply --3way "$a/.worktrees/move.patch" 2>/dev/null && rm "$a/.worktrees/move.patch"
# apply --3way stages what it applies; the moved changes arrive as they were (scaffold.md, move)
[ -n "$files" ] && git -C "$a/.worktrees/$u" restore --staged -- $files
echo "built v0.4 $(basename "$a"): unit $u from $start, main clean=$([ -z "$(git -C "$a" status --porcelain)" ] && echo yes || echo no), unit dirty=$(git -C "$a/.worktrees/$u" status --short | wc -l | tr -d ' ')"
