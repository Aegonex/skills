#!/bin/bash
# Builds two pristine fixture repos under $1: stale-app (has state files, but stale) and fresh-app (no state files)
set -e; base="$1"; mkdir -p "$base"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
# ---------- stale-app ----------
a="$base/stale-app"; rm -rf "$a"; mkdir -p "$a/src" "$a/docs"; cd "$a"; git init -q -b main
cat > package.json <<'EOT'
{ "name": "stale-app", "version": "0.3.0", "scripts": { "dev": "tsx src/index.ts", "test": "vitest run", "build": "tsc -p ." }, "dependencies": { "fastify": "^5.0.0", "jose": "^6.0.0" }, "devDependencies": { "typescript": "^5.6.0", "vitest": "^3.0.0", "tsx": "^4.0.0" } }
EOT
cat > src/index.ts <<'EOT'
import Fastify from "fastify";
import { verifyToken } from "./auth";
const app = Fastify();
app.get("/me", async (req) => verifyToken(String(req.headers.authorization ?? "")));
app.listen({ port: 3000 });
EOT
cat > src/auth.ts <<'EOT'
import { jwtVerify } from "jose";
const secret = new TextEncoder().encode(process.env.JWT_SECRET ?? "dev");
export async function verifyToken(header: string) {
  const token = header.replace(/^Bearer /, "");
  const { payload } = await jwtVerify(token, secret);
  // AIDEV-TODO: refresh-token path — issue a new access token when exp < 60s (ROADMAP M2)
  return payload;
}
EOT
cat > src/db.ts <<'EOT'
import { Pool } from "pg";
export const pool = new Pool();
export async function withTx<T>(fn: (c: any) => Promise<T>) {
  const c = await pool.connect();
  // AIDEV-NOTE: BEGIN must run before SET LOCAL — swapping them caused the prod race in July
  await c.query("BEGIN");
  await c.query("SET LOCAL statement_timeout = 5000");
  try { const r = await fn(c); await c.query("COMMIT"); return r; }
  catch (e) { await c.query("ROLLBACK"); throw e; } finally { c.release(); }
}
EOT
cat > AGENTS.md <<'EOT'
# stale-app

## Stack
TypeScript, Fastify 5, jose (JWT), Postgres via pg. Node 22.

## Commands
- `npm run dev` — start on :3000
- `npm test` — vitest (unit only, no DB)
- `npm run build` — tsc

## Layout
Scratch: docs/scratch/

## Rules
- Conventional commits.
- Never log tokens or secrets.
- DB access only through `withTx` in src/db.ts.
EOT
cat > ROADMAP.md <<'EOT'
# ROADMAP — stale-app

Goal: a small auth-protected API for the internal dashboard.

## Milestones
- [x] M1 — Fastify skeleton + JWT verify · done when: GET /me returns the token payload · closed 2026-08-20
- [ ] M2 — Refresh tokens · done when: an access token expiring within 60s is replaced transparently
  - docs: docs/m2-notes.md
  - [x] decide on rotation strategy · done when: the decision is recorded below
  - [ ] issue a new access token when exp < 60s · done when: `npm test` passes the refresh case in src/auth.test.ts
  - [ ] expiry unit tests · done when: `npm test` runs a real expired-token case
- [ ] M3 — Rate limiting · done when: 429 after 100 requests per minute per token

## Not doing
- OAuth login: M4 at the earliest, no customer asks for it yet.

## Decisions
- 2026-08-20 — jose over jsonwebtoken (ESM, maintained).
- 2026-08-28 — single-use refresh tokens, 7 day lifetime (simplest revocation story).

## Constraints
- Node 22. No new runtime dependency without a decision line.
EOT
printf '# M2 notes\nRotation: single-use refresh, 7d. Open question: clock skew on mobile.\n' > docs/m2-notes.md
printf '# stale-app\nInternal API.\n' > README.md
git add -A; GIT_AUTHOR_DATE="2026-08-29T17:00:00+07:00" GIT_COMMITTER_DATE="2026-08-29T17:00:00+07:00" git commit -qm "feat: jwt verify, state files"
pre=$(git rev-parse --short HEAD)
git checkout -q -b feat/auth-refresh
cat > HANDOFF.md <<EOT
# HANDOFF — 2026-08-30

Branch: feat/auth-refresh · HEAD: $pre

## Stopped at
Implementing the refresh path in \`src/auth.ts\` (see the AIDEV-TODO there).
Rotation strategy is decided (ROADMAP M2). Nothing else is in flight.

## Next step
Write the expiry unit test in \`src/auth.test.ts\` first, then implement refresh.

## Dead ends
- jsonwebtoken v9 breaks under ESM here — do not retry, jose is the choice.

## Notes for the next session
- \`npm test\` needs \`JWT_SECRET=dev\` exported, the default is not picked up under vitest.

## Suggested skills
- aegonex-init
EOT
# the handoff commit also touches source: init must not count it as drift
sed -i '' 's|// AIDEV-TODO: refresh-token path|// refresh path lands in M2; AIDEV-TODO: refresh-token path|' src/auth.ts
git add -A; GIT_AUTHOR_DATE="2026-08-30T10:00:00+07:00" GIT_COMMITTER_DATE="2026-08-30T10:00:00+07:00" git commit -qm "docs: handoff 2026-08-30"
cat > src/auth.test.ts <<'EOT'
import { describe, it, expect } from "vitest";
describe("verifyToken", () => { it("rejects empty header", async () => { expect(true).toBe(true); }); });
EOT
git add -A; GIT_AUTHOR_DATE="2026-09-01T18:00:00+07:00" GIT_COMMITTER_DATE="2026-09-01T18:00:00+07:00" git commit -qm "test: scaffold expiry test file"
git checkout -q -b fix/db-race
# uncommitted change HANDOFF knows nothing about
sed -i '' 's/statement_timeout = 5000/statement_timeout = 2000/' src/db.ts
echo "built stale-app: branch=$(git branch --show-current) handoff-head=$pre dirty=$(git status --short | wc -l | tr -d ' ')"
# ---------- fresh-app ----------
b="$base/fresh-app"; rm -rf "$b"; mkdir -p "$b/src"; cd "$b"; git init -q -b main
cat > package.json <<'EOT'
{ "name": "fresh-app", "version": "0.1.0", "scripts": { "dev": "vite", "test": "vitest run", "build": "vite build", "lint": "eslint ." }, "dependencies": { "react": "^19.0.0", "react-dom": "^19.0.0" }, "devDependencies": { "vite": "^6.0.0", "vitest": "^3.0.0", "typescript": "^5.6.0", "eslint": "^9.0.0" } }
EOT
printf 'export function App() { return <h1>fresh</h1>; }\n' > src/App.tsx
printf '# fresh-app\nA new dashboard.\n' > README.md
git add -A; GIT_AUTHOR_DATE="2026-09-02T09:00:00+07:00" GIT_COMMITTER_DATE="2026-09-02T09:00:00+07:00" git commit -qm "chore: vite + react scaffold"
echo "built fresh-app: branch=$(git branch --show-current)"
