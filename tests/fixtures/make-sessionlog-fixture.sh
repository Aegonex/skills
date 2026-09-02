#!/bin/bash
# sessionlog-app under $1: stale-app whose last session wrote aegonex-note lines but never ran exit;
# its HANDOFF HEAD sha no longer exists (rebased), so init must fall back to --since.
set -e; base="$1"; src="$2"; a="$base/sessionlog-app"; rm -rf "$a"; cp -R "$src/stale-app" "$a"; cd "$a"
git checkout -q -- src/db.ts; git checkout -q feat/auth-refresh
sed -i '' 's|^Branch: feat/auth-refresh · HEAD: .*|Branch: feat/auth-refresh · HEAD: deadbee|' HANDOFF.md
cat >> HANDOFF.md <<'EOT'

## Session log
- 10:12 decision: refresh window is 60s, not configurable (keep it simple)
- 10:40 dead end: reading exp from the raw header before jwtVerify; jose rejects it, verify first
- 11:05 fact: npm test needs JWT_SECRET=dev in the shell
EOT
echo "built sessionlog-app: branch=$(git branch --show-current) dirty=$(git status --short | tr '\n' ' ')"
