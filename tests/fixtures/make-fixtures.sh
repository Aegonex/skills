#!/bin/bash
# Builds two pristine fixture repos under $1: stale-app (has state files, but stale) and fresh-app (no state files)
set -e; base="$1"; mkdir -p "$base"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
# ---------- stale-app ----------
a="$base/stale-app"; rm -rf "$a"; mkdir -p "$a/src"; cd "$a"; git init -q -b main
cat > package.json <<'EOF'
{ "name": "stale-app", "version": "0.3.0", "scripts": { "dev": "tsx src/index.ts", "test": "vitest run", "build": "tsc -p ." }, "dependencies": { "fastify": "^5.0.0", "jose": "^6.0.0" }, "devDependencies": { "typescript": "^5.6.0", "vitest": "^3.0.0", "tsx": "^4.0.0" } }
EOF
cat > src/index.ts <<'EOF'
import Fastify from "fastify";
import { verifyToken } from "./auth";
const app = Fastify();
app.get("/me", async (req) => verifyToken(String(req.headers.authorization ?? "")));
app.listen({ port: 3000 });
EOF
cat > src/auth.ts <<'EOF'
import { jwtVerify } from "jose";
const secret = new TextEncoder().encode(process.env.JWT_SECRET ?? "dev");
export async function verifyToken(header: string) {
  const token = header.replace(/^Bearer /, "");
  const { payload } = await jwtVerify(token, secret);
  // AIDEV-TODO: refresh-token path — issue a new access token when exp < 60s (ROADMAP M2)
  return payload;
}
EOF
cat > src/db.ts <<'EOF'
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
EOF
cat > AGENTS.md <<'EOF'
# stale-app

## Stack
TypeScript, Fastify 5, jose (JWT), Postgres via pg. Node 22.

## Commands
- `npm run dev` — start on :3000
- `npm test` — vitest (unit only, no DB)
- `npm run build` — tsc

## Rules
- Conventional commits.
- Never log tokens or secrets.
- DB access only through `withTx` in src/db.ts.
EOF
cat > ROADMAP.md <<'EOF'
# ROADMAP — stale-app

Goal: a small auth-protected API for the internal dashboard.

## Milestones
- [x] M1 — Fastify skeleton + JWT verify (done 2026-08-20)
- [ ] M2 — Refresh tokens (in progress)
  - [x] decide on rotation strategy (single-use refresh, 7d)
  - [ ] issue new access token when exp < 60s
  - [ ] expiry unit tests
- [ ] M3 — Rate limiting

## Decisions
- jose over jsonwebtoken (ESM, maintained).
EOF
cat > HANDOFF.md <<'EOF'
# HANDOFF — 2026-08-30

Branch: feat/auth-refresh

## Stopped at
Implementing the refresh path in `src/auth.ts` (see the AIDEV-TODO there).
Rotation strategy is decided (ROADMAP M2). Nothing else is in flight.

## Next step
Write the expiry unit test in `src/auth.test.ts` first, then implement refresh.

## Dead ends
- jsonwebtoken v9 breaks under ESM here — do not retry, jose is the choice.

## Suggested skills
- tdd for the expiry test.
EOF
printf '# stale-app\nInternal API.\n' > README.md
git add -A; GIT_AUTHOR_DATE="2026-08-30T10:00:00+07:00" GIT_COMMITTER_DATE="2026-08-30T10:00:00+07:00" git commit -qm "feat: jwt verify, state files, handoff"
git checkout -q -b feat/auth-refresh
cat > src/auth.test.ts <<'EOF'
import { describe, it, expect } from "vitest";
describe("verifyToken", () => { it("rejects empty header", async () => { expect(true).toBe(true); }); });
EOF
git add -A; GIT_AUTHOR_DATE="2026-09-01T18:00:00+07:00" GIT_COMMITTER_DATE="2026-09-01T18:00:00+07:00" git commit -qm "test: scaffold expiry test file"
git checkout -q -b fix/db-race
# uncommitted change HANDOFF knows nothing about
sed -i '' 's/statement_timeout = 5000/statement_timeout = 2000/' src/db.ts
echo "built stale-app: branch=$(git branch --show-current) dirty=$(git status --short | wc -l | tr -d ' ')"
# ---------- fresh-app ----------
b="$base/fresh-app"; rm -rf "$b"; mkdir -p "$b/src"; cd "$b"; git init -q -b main
cat > package.json <<'EOF'
{ "name": "fresh-app", "version": "0.1.0", "scripts": { "dev": "vite", "test": "vitest run", "build": "vite build", "lint": "eslint ." }, "dependencies": { "react": "^19.0.0", "react-dom": "^19.0.0" }, "devDependencies": { "vite": "^6.0.0", "vitest": "^3.0.0", "typescript": "^5.6.0", "eslint": "^9.0.0" } }
EOF
printf 'export function App() { return <h1>fresh</h1>; }\n' > src/App.tsx
printf '# fresh-app\nA new dashboard.\n' > README.md
git add -A; GIT_AUTHOR_DATE="2026-09-02T09:00:00+07:00" GIT_COMMITTER_DATE="2026-09-02T09:00:00+07:00" git commit -qm "chore: vite + react scaffold"
echo "built fresh-app: branch=$(git branch --show-current)"
