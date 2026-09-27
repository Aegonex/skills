## Repos (aegonex 0.5)
- **Parent:** the folder above holds the project's other repos and is never a repo: no `git init`, file or commit there.
  Units, state files, commands and go stay per repo; one session per repo at a time; milestone numbers never change.
  A session inside one repo changes only that repo; work that also needs another repo starts in the parent folder.
- **After:** `after: <repo> <v>` on a unit's ROADMAP line, or `t-<slug> after: <repo> <v>` in HANDOFF.md (State files):
  it lands only once `<main>/../<repo>` has no `aegonex/<v>` branch and, for `m<k>`, `<remote>/<Base>:ROADMAP.md` there has
  `- [x] M<k> ... closed`. Not yet: stop, name it; git only reads there. The parent lands providers first; a refusal stops.
