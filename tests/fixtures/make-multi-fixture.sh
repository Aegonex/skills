#!/bin/bash
# usage: make-multi-fixture.sh <dir> [--protected <r>] [--repos <n>] [--ticked] [--no-milestones] [--no-repos-section] [--git-init-parent]
# Builds <dir>/shop, a plain folder (not a repo) holding the repos of one project, as a parent session sees it:
#   backend   set up (v0.4 sections + Repos section), m3 open: M3 cart discount API, 2 of 3 steps ticked (--ticked: all)
#   frontend  set up likewise, m5 open: M5 cart page, every step ticked, `after: backend m3` on its line
#   admin     one commit, not set up
#   docs/, notes.txt   not repos
# Bare remotes live in <dir>/remotes (outside shop); each post-receive hook appends "<repo> <ref>" to <dir>/push-order.log.
# --no-milestones: no unit folder anywhere; --no-repos-section: backend and frontend lack the Repos section;
# --protected <r>: <r>'s remote refuses pushes to main; --repos <n>: extra plain repos up to n; --git-init-parent: shop is git-init'ed.
set -e
D="${1:?usage: make-multi-fixture.sh <dir> [options]}"; shift
PROT=""; NREPOS=3; TICKED=""; NOMILE=""; NOREPOS=""; GITPARENT=""
while [ $# -gt 0 ]; do case "$1" in
  --protected) PROT="$2"; shift 2;; --repos) NREPOS="$2"; shift 2;; --ticked) TICKED=1; shift;;
  --no-milestones) NOMILE=1; shift;; --no-repos-section) NOREPOS=1; shift;; --git-init-parent) GITPARENT=1; shift;;
  *) echo "unknown option $1" >&2; exit 1;; esac; done
SK=$(cd "$(dirname "$0")/../../skills" && pwd)
mkdir -p "$D"; D=$(cd "$D" && pwd -P)
git -C "$D" rev-parse --git-dir >/dev/null 2>&1 && { echo "refuse: $D is inside a git repo" >&2; exit 1; }
export GIT_CEILING_DIRECTORIES="$D" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=f@x.io GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=f@x.io
P="$D/shop"; R="$D/remotes"; rm -rf "$P" "$R" "$D/push-order.log"; mkdir -p "$P" "$R"
remote() { o="$R/$1.git"; git init -q --bare -b main "$o"
  printf '#!/bin/sh\nwhile read o n ref; do echo "%s $ref" >> "%s/push-order.log"; done\n' "$1" "$D" > "$o/hooks/post-receive"; chmod +x "$o/hooks/post-receive"
  true; }
setup() { a="$P/$1"   # aegonex setup as init's go writes it, pushed (the project was set up earlier)
  printf '\n' >> "$a/AGENTS.md"; sed -n '/^## Working mode (aegonex 0.4)/,$p' "$SK/aegonex-init/assets/AGENTS.md" \
    | sed 's/^Base: .*/Base: main · Remote: origin/' >> "$a/AGENTS.md"
  [ -z "$NOREPOS" ] && { printf '\n' >> "$a/AGENTS.md"; cat "$SK/aegonex-init/assets/AGENTS-repos.md" >> "$a/AGENTS.md"; }
  printf '@AGENTS.md\n' > "$a/CLAUDE.md"; mkdir -p "$a/.worktrees"; printf '*\n' > "$a/.worktrees/.gitignore"
  git -C "$a" add -- AGENTS.md CLAUDE.md; git -C "$a" commit -q -m "chore: aegonex setup" -- AGENTS.md CLAUDE.md
  git -C "$a" push -q origin main; git -C "$a" fetch -q origin; }
repo() { a="$P/$1"; mkdir -p "$a"; git init -q -b main "$a"; remote "$1"; git -C "$a" remote add origin "$R/$1.git"; }
first_push() { git -C "$P/$1" push -q origin main; git -C "$P/$1" fetch -q origin; git -C "$P/$1" remote set-head origin main; }
milestone() { a="$P/$1"; u="$2"; shift 2   # open <u> from main and commit its plan (plan's go)
  git -C "$a" worktree add -q -b "aegonex/$u" "$a/.worktrees/$u" main
  printf '%s\n' "$@" > "$a/.worktrees/$u/ROADMAP.md.new"; cat "$a/.worktrees/$u/ROADMAP.md.new" >> "$a/.worktrees/$u/ROADMAP.md"; rm "$a/.worktrees/$u/ROADMAP.md.new"
  git -C "$a/.worktrees/$u" add -- ROADMAP.md; git -C "$a/.worktrees/$u" commit -q -m "docs: plan $(echo "$u" | tr m M)" -- ROADMAP.md; }

# ---- backend: an API that returns the cart
repo backend; b="$P/backend"; mkdir -p "$b/src" "$b/test"
printf '{ "name": "shop-backend", "version": "0.3.0", "type": "module", "scripts": { "test": "node --test" } }\n' > "$b/package.json"
printf 'export function getCart(items) {\n  const total = items.reduce((s, i) => s + i.price * i.qty, 0);\n  return { items, total };\n}\n' > "$b/src/cart.js"
printf 'import { test } from "node:test";\nimport assert from "node:assert/strict";\nimport { getCart } from "../src/cart.js";\n\ntest("getCart totals the items", () => {\n  assert.equal(getCart([{ price: 10, qty: 2 }]).total, 20);\n});\n' > "$b/test/cart.test.js"
printf '# shop-backend\n\n## Stack\nNode 22+, ES modules, no dependencies.\n\n## Commands\n- `none` — install (run in each new folder)\n- `node --test` — run tests\n\n## Rules\n- The /cart response shape is shared with frontend.\n' > "$b/AGENTS.md"
printf '# Roadmap\n\nGoal: a shop API.\n\n## Milestones\n- [x] M1 — products · closed 2026-09-01\n- [x] M2 — cart · closed 2026-09-10\n' > "$b/ROADMAP.md"
git -C "$b" add -- package.json src test AGENTS.md ROADMAP.md; git -C "$b" commit -q -m "chore: scaffold"
first_push backend; setup backend

# ---- frontend: a cart page that renders what /cart returns
repo frontend; f="$P/frontend"; mkdir -p "$f/src" "$f/test"
printf '{ "name": "shop-frontend", "version": "0.5.0", "type": "module", "scripts": { "test": "node --test" } }\n' > "$f/package.json"
printf 'export function renderCart(cart) {\n  return cart.items.map((i) => `${i.name} x${i.qty}`).concat(`Total: ${cart.total}`).join("\\n");\n}\n' > "$f/src/cartView.js"
printf 'import { test } from "node:test";\nimport assert from "node:assert/strict";\nimport { renderCart } from "../src/cartView.js";\n\ntest("renderCart shows the total", () => {\n  assert.match(renderCart({ items: [{ name: "tea", qty: 1 }], total: 5 }), /Total: 5/);\n});\n' > "$f/test/cartView.test.js"
printf '# shop-frontend\n\n## Stack\nNode 22+, ES modules, no dependencies.\n\n## Commands\n- `none` — install (run in each new folder)\n- `node --test` — run tests\n\n## Rules\n- Render only what /cart returns.\n' > "$f/AGENTS.md"
printf '# Roadmap\n\nGoal: the shop web pages.\n\n## Milestones\n- [x] M1 — layout · closed 2026-08-20\n- [x] M2 — product list · closed 2026-08-28\n- [x] M3 — product page · closed 2026-09-03\n- [x] M4 — login · closed 2026-09-12\n' > "$f/ROADMAP.md"
git -C "$f" add -- package.json src test AGENTS.md ROADMAP.md; git -C "$f" commit -q -m "chore: scaffold"
first_push frontend; setup frontend

# ---- admin: a repo never set up
repo admin; printf '# shop-admin\n\nBack-office pages.\n' > "$P/admin/README.md"
git -C "$P/admin" add -- README.md; git -C "$P/admin" commit -q -m "chore: scaffold"; first_push admin

# ---- extra repos (--repos n)
k=4; while [ "$k" -le "$NREPOS" ]; do repo "svc$k"; printf '# svc%s\n' "$k" > "$P/svc$k/README.md"
  git -C "$P/svc$k" add -- README.md; git -C "$P/svc$k" commit -q -m init; first_push "svc$k"; k=$((k+1)); done

# ---- not repos
mkdir -p "$P/docs"; printf '# Shop notes\n\nThe team meets on Mondays.\n' > "$P/docs/overview.md"; printf 'buy more tea\n' > "$P/notes.txt"

# ---- open milestones
if [ -z "$NOMILE" ]; then
  s3='- [ ] step 3: `node --test` covers a discount code · done when: `node --test` passes'
  [ -n "$TICKED" ] && s3='- [x] step 3: `node --test` covers a discount code · done when: `node --test` passes'
  milestone backend m3 '- [ ] M3 — cart discount API · done when: `node --test` passes and /cart returns discount' \
    '  - [x] step 1: discount codes table · done when: `node --test` passes' \
    '  - [x] step 2: apply a code in getCart · done when: `node --test` passes' "  $s3"
  milestone frontend m5 '- [ ] M5 — cart page discount · after: backend m3 · done when: `node --test` passes and the page shows the discount' \
    '  - [x] step 1: discount line in renderCart · done when: `node --test` passes' \
    '  - [x] step 2: hide the line when there is no discount · done when: `node --test` passes'
  # the ticked steps' work, committed in the unit folders
  w="$P/backend/.worktrees/m3"
  printf 'export const CODES = { SAVE10: 10, SAVE20: 20 };\n' > "$w/src/discount.js"
  git -C "$w" add -- src/discount.js; git -C "$w" commit -q -m "feat: discount codes table" -- src/discount.js
  printf 'import { CODES } from "./discount.js";\n\nexport function getCart(items, code) {\n  const subtotal = items.reduce((s, i) => s + i.price * i.qty, 0);\n  const discount = CODES[code] ?? 0;\n  return { items, discount, total: subtotal - discount };\n}\n' > "$w/src/cart.js"
  git -C "$w" commit -q -m "feat: apply a code in getCart" -- src/cart.js
  if [ -n "$TICKED" ]; then
    printf '\ntest("getCart applies a discount code", () => {\n  assert.equal(getCart([{ price: 50, qty: 1 }], "SAVE10").total, 40);\n});\n' >> "$w/test/cart.test.js"
    git -C "$w" commit -q -m "test: discount code" -- test/cart.test.js
  fi
  w="$P/frontend/.worktrees/m5"
  printf 'export function renderCart(cart) {\n  const lines = cart.items.map((i) => `${i.name} x${i.qty}`);\n  if (cart.discount > 0) lines.push(`Discount: ${cart.discount}`);\n  return lines.concat(`Total: ${cart.total}`).join("\\n");\n}\n' > "$w/src/cartView.js"
  git -C "$w" commit -q -m "feat: discount line in renderCart" -- src/cartView.js
  printf '\ntest("renderCart hides the discount line when there is none", () => {\n  assert.doesNotMatch(renderCart({ items: [], discount: 0, total: 5 }), /Discount/);\n});\n' >> "$w/test/cartView.test.js"
  git -C "$w" commit -q -m "test: hide the discount line" -- test/cartView.test.js
fi
if [ -n "$PROT" ]; then o="$R/$PROT.git"   # protected last, so the fixture's own pushes go through
  printf '#!/bin/sh\nwhile read o n ref; do [ "$ref" = refs/heads/main ] && [ -z "$ALLOW" ] && { echo "protected branch hook: changes must be made through a pull request"; exit 1; }; done; exit 0\n' > "$o/hooks/pre-receive"; chmod +x "$o/hooks/pre-receive"; fi
rm -f "$D/push-order.log"   # the log starts empty: only the session's pushes are listed
[ -n "$GITPARENT" ] && git init -q -b main "$P"
echo "built $P: $(ls "$P" | tr '\n' ' ')"
