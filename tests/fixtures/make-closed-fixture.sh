#!/bin/bash
# closed-app under $1: stale-app with M2 implemented and every step's `done when` runnable without dependencies.
# $3 = --failing builds closed-app-failing, where one check fails.
set -e; base="$1"; src="$2"; name="closed-app"; [ "$3" = "--failing" ] && name="closed-app-failing"
a="$base/$name"; rm -rf "$a"; cp -R "$src/stale-app" "$a"; cd "$a"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
git checkout -q -- src/db.ts; git checkout -q feat/auth-refresh
mkdir -p tests docs
window=60; [ "$3" = "--failing" ] && window=120
cat > src/auth.ts <<EOT
import { jwtVerify, SignJWT } from "jose";
const secret = new TextEncoder().encode(process.env.JWT_SECRET ?? "dev");
const REFRESH_WINDOW_S = $window;
export async function verifyToken(header: string) {
  const token = header.replace(/^Bearer /, "");
  const { payload } = await jwtVerify(token, secret);
  if (payload.exp && payload.exp - Date.now() / 1000 < REFRESH_WINDOW_S) {
    const refreshed = await new SignJWT({ sub: payload.sub }).setProtectedHeader({ alg: "HS256" }).setExpirationTime("15m").sign(secret);
    return { ...payload, refreshed };
  }
  return payload;
}
EOT
cat > src/auth.test.ts <<'EOT'
import { describe, it, expect } from "vitest";
import { SignJWT } from "jose";
import { verifyToken } from "./auth";
const secret = new TextEncoder().encode("dev");
describe("verifyToken", () => {
  it("rejects an expired token", async () => {
    const t = await new SignJWT({}).setProtectedHeader({ alg: "HS256" }).setExpirationTime("-1s").sign(secret);
    await expect(verifyToken(`Bearer ${t}`)).rejects.toThrow();
  });
  it("refreshes a token expiring within the window", async () => {
    const t = await new SignJWT({ sub: "u1" }).setProtectedHeader({ alg: "HS256" }).setExpirationTime("30s").sign(secret);
    await expect(verifyToken(`Bearer ${t}`)).resolves.toHaveProperty("refreshed");
  });
});
EOT
printf '#!/bin/bash\n# done-when check for "issue a new access token when exp < 60s"\ngrep -q "REFRESH_WINDOW_S = 60;" src/auth.ts && grep -q "refreshed" src/auth.ts && echo "refresh check: ok"\n' > tests/check-refresh.sh
printf '#!/bin/bash\n# done-when check for "expiry unit tests"\ngrep -q "rejects an expired token" src/auth.test.ts && echo "expiry check: ok"\n' > tests/check-expiry.sh
chmod +x tests/*.sh
cat > ROADMAP.md <<'EOT'
# ROADMAP — closed-app

Goal: a small auth-protected API for the internal dashboard.

## Milestones
- [x] M1 — Fastify skeleton + JWT verify · done when: GET /me returns the token payload · closed 2026-08-20
- [ ] M2 — Refresh tokens · done when: `bash tests/check-refresh.sh` and `bash tests/check-expiry.sh` both pass
  - docs: docs/m2-notes.md docs/m2-spec.md
  - [x] decide on rotation strategy · done when: the decision is recorded below
  - [x] issue a new access token when exp < 60s · done when: `bash tests/check-refresh.sh` passes
  - [x] expiry unit tests · done when: `bash tests/check-expiry.sh` passes
- [ ] M3 — Rate limiting · done when: 429 after 100 requests per minute per token

## Not doing
- OAuth login: M4 at the earliest, no customer asks for it yet.
- Mobile clock-skew tolerance: only relevant to M2, dropped after the 60s decision.

## Decisions
- 2026-08-20 — jose over jsonwebtoken (ESM, maintained).
- 2026-08-28 — single-use refresh tokens, 7 day lifetime (simplest revocation story).
- 2026-09-02 — refresh window fixed at 60s, not configurable (keep it simple).

## Constraints
- Node 22. No new runtime dependency without a decision line.
EOT
printf '# M2 spec\nRefresh when exp < 60s. Single-use refresh, 7d.\n' > docs/m2-spec.md
git add -A; GIT_AUTHOR_DATE="2026-09-02T14:00:00+07:00" GIT_COMMITTER_DATE="2026-09-02T14:00:00+07:00" git commit -qm "feat: refresh path, expiry tests, M2 docs"
pre=$(git rev-parse --short HEAD)
cat > HANDOFF.md <<EOT
# HANDOFF — 2026-09-02

Branch: feat/auth-refresh · HEAD: $pre

## Stopped at
M2 implemented in \`src/auth.ts\`, tests in \`src/auth.test.ts\`, both committed. Nothing in flight.

## Next step
Close M2 with aegonex-done.

## Dead ends
- jsonwebtoken v9 breaks under ESM here — jose is the choice.
- Reading exp from the raw header before jwtVerify: jose rejects it, verification must come first.
- Making the refresh window configurable: two config paths for one number, dropped.

## Notes for the next session
- \`npm test\` needs \`JWT_SECRET=dev\` exported.

## Suggested skills
- aegonex-init
- aegonex-done
EOT
git add -A; GIT_AUTHOR_DATE="2026-09-02T14:05:00+07:00" GIT_COMMITTER_DATE="2026-09-02T14:05:00+07:00" git commit -qm "docs: handoff 2026-09-02"
mkdir -p docs/scratch; printf 'trying refresh with 30s window: no\n' > docs/scratch/try.md   # untracked scratch file
echo "built $name: branch=$(git branch --show-current) handoff-head=$pre dirty=$(git status --short | tr '\n' ' ')"
