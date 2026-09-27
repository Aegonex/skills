**Opened:** `.worktrees/t-db-race`
moved `src/db.ts` (`fix/db-race` kept) · set up: `AGENTS.md`, `CLAUDE.md` · reopen your editor there

The `src/db.ts` change lowers `statement_timeout` in `withTx` from 5000 to 2000 ms; HANDOFF.md does not say why.
