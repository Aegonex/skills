#!/bin/bash
# planned-app under $1: stale-app after M2 was finished and handed off; M3 has no steps yet, so init must point to aegonex-plan
set -e; base="$1"; src="$2"; a="$base/planned-app"; rm -rf "$a"; cp -R "$src/stale-app" "$a"; cd "$a"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
git checkout -q -- src/db.ts; git checkout -q feat/auth-refresh
sed -i '' 's|^- \[ \] M2 — Refresh tokens|- [x] M2 — Refresh tokens|; s|^  - \[ \] issue a new access token|  - [x] issue a new access token|; s|^  - \[ \] expiry unit tests|  - [x] expiry unit tests|' ROADMAP.md
sed -i '' '/AIDEV-TODO: refresh-token path/d' src/auth.ts
git add -A; GIT_AUTHOR_DATE="2026-09-02T12:00:00+07:00" GIT_COMMITTER_DATE="2026-09-02T12:00:00+07:00" git commit -qm "feat: refresh path, M2 steps done"
pre=$(git rev-parse --short HEAD)
cat > HANDOFF.md <<EOT
# HANDOFF — 2026-09-02

Branch: feat/auth-refresh · HEAD: $pre

## Stopped at
M2 (refresh tokens) is finished: every step ticked, refresh path in \`src/auth.ts\`, tests in \`src/auth.test.ts\`. Nothing in flight.

## Next step
Plan M3 (rate limiting) with aegonex-plan; it has no steps yet.

## Dead ends
- jsonwebtoken v9 breaks under ESM here — jose is the choice.

## Notes for the next session
- \`npm test\` needs \`JWT_SECRET=dev\` exported.

## Suggested skills
- aegonex-init
- aegonex-plan
EOT
git add -A; GIT_AUTHOR_DATE="2026-09-02T12:05:00+07:00" GIT_COMMITTER_DATE="2026-09-02T12:05:00+07:00" git commit -qm "docs: handoff 2026-09-02"
echo "built planned-app: branch=$(git branch --show-current) handoff-head=$pre dirty=$(git status --short | wc -l | tr -d ' ')"
