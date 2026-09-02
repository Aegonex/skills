#!/bin/bash
# Builds session-end-app under $1: stale-app after a day of work on branch feat/auth-refresh
set -e; base="$1"; src="$2"; a="$base/session-end-app"; rm -rf "$a"; cp -R "$src/stale-app" "$a"; cd "$a"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
git checkout -q -- src/db.ts            # drop the dirty db change from the stale fixture
git checkout -q feat/auth-refresh
# the open step already carries (in progress) from an earlier exit: exit must not add a second one
sed -i "" "s|^  - \[ \] issue a new access token\(.*\)\$|  - [ ] issue a new access token\1 (in progress)|" ROADMAP.md
# work done this session, committed: real expiry test
cat > src/auth.test.ts <<'EOF'
import { describe, it, expect } from "vitest";
import { SignJWT } from "jose";
import { verifyToken } from "./auth";
const secret = new TextEncoder().encode("dev");
describe("verifyToken", () => {
  it("rejects an expired token", async () => {
    const t = await new SignJWT({}).setProtectedHeader({ alg: "HS256" }).setExpirationTime("-1s").sign(secret);
    await expect(verifyToken(`Bearer ${t}`)).rejects.toThrow();
  });
  it("accepts a fresh token", async () => {
    const t = await new SignJWT({ sub: "u1" }).setProtectedHeader({ alg: "HS256" }).setExpirationTime("2m").sign(secret);
    await expect(verifyToken(`Bearer ${t}`)).resolves.toMatchObject({ sub: "u1" });
  });
});
EOF
git add -A; GIT_AUTHOR_DATE="2026-09-02T11:10:00+07:00" GIT_COMMITTER_DATE="2026-09-02T11:10:00+07:00" git commit -qm "test: expiry unit tests for verifyToken"
# work in flight, NOT committed: refresh path half done
cat > src/auth.ts <<'EOF'
import { jwtVerify, SignJWT } from "jose";
const secret = new TextEncoder().encode(process.env.JWT_SECRET ?? "dev");
const REFRESH_WINDOW_S = 120; // decided today: 120s, not 60s (mobile clock skew)
export async function verifyToken(header: string) {
  const token = header.replace(/^Bearer /, "");
  const { payload } = await jwtVerify(token, secret);
  // AIDEV-TODO: refresh-token path — issue a new access token when exp < REFRESH_WINDOW_S (ROADMAP M2)
  if (payload.exp && payload.exp - Date.now() / 1000 < REFRESH_WINDOW_S) {
    // TODO wire rotation store; issuing without single-use check for now
    const fresh = await new SignJWT({ sub: payload.sub }).setProtectedHeader({ alg: "HS256" }).setExpirationTime("15m").sign(secret);
    return { ...payload, refreshed: fresh };
  }
  return payload;
}
EOF
echo "built session-end-app: branch=$(git branch --show-current) head=$(git rev-parse --short HEAD) dirty=$(git status --short | tr '\n' ' ')"
