# 1. Persistence moves to Postgres on Supabase

**Status:** accepted, not yet implemented
**Date:** 2026-08-16
**Applies when:** the Rust backend is next worked on. Nothing here is urgent.

## Decision

When the backend is fixed, persistence moves from MongoDB Atlas to Postgres on
Supabase. The surviving data is re-created from scratch rather than migrated.

## Why the engine was not the deciding factor

What actually needs storing is small, keyed and read-heavy: sites by program
address, domains by name, URL-to-token mappings by hash, and eventually the
per-site adapters. Both engines handle that shape without difficulty. The
choice was made on operational grounds, not performance.

## What decided it

**Row Level Security closes a live hole structurally.** `PUT /api/sites/{program_address}`
currently has no authentication of any kind — anyone can overwrite any site
record. As an RLS policy, "only the owner may update this row" is enforced by
the database no matter what the application does. For a product whose pitch is
trust, authorisation belonging below the application layer is worth more than
any query-performance argument.

**The Rust service may not need to survive.** With RLS handling authorisation,
clients can talk to PostgREST directly, and Edge Functions can hold the few
operations that need a secret — the Pinata upload key in particular. That
retires a service which has never successfully booted (invalid `declare_id!`
values propagate into a startup `?`) and whose routes roughly two-thirds of the
mobile app never calls.

**The schema becomes visible.** Today it is implicit across fifteen files, with
indexes on three of eighteen collections and no way to see the whole shape.
Versioned SQL is reviewable in a diff. `migrations/` already contains three
Postgres files from an earlier intent that was never carried through.

**A fresh database was required regardless.** The Atlas credential was public in
this repository from 2025-12-02, so that cluster has to be considered
compromised for both read and write. Staying on MongoDB still meant provisioning
new and moving data. The additional cost of choosing Postgres is the difference
between those two, not the whole migration.

**One less system to run.** Supabase is already operated for two other projects.

## What does not move

This is the substantive part. Eighteen collections exist; about four deserve to.

**Keep** — `sites`, `domains`, `link_mappings`, and a minimal `users` profile
record keyed by wallet.

**Move to the device, do not host** — `browser_history`, `browser_sessions`,
`bookmarks`. These are real features, but a privacy browser holding a
server-side record of what its users looked at is the most self-contradictory
thing in the codebase. They belong in local storage on the phone.

**Delete outright** — `wallets` holds custodial private keys under a repeating
XOR that the code documents as AES-256-GCM; the key is recoverable from the
cleartext pubkey stored in the same document. The mobile app already has a
local, non-custodial wallet, so this collection is pure liability and must not
be carried anywhere. `dapp_connections` records permissions that no handler
enforces.

**Delete as analytics** — `site_analytics`, `user_engagement`,
`performance_metrics`, `content_analysis`. Collecting behavioural analytics on
the users of an anonymity product defeats the product.

**Delete as rebuildable cache** — `token_metadata`, `nft_metadata`,
`price_cache`, `pending_transactions`. These are additionally poisoned:
placeholder values (`"UNKNOWN"`, a hardcoded SOL price of `100.0`) were written
into them as though real, so migrating them would carry fabricated data
forward into a clean system.

## Sequence

1. Rotate the MongoDB Atlas credential. Still outstanding, and the only item
   here that worsens with time. Deleting the line does not help — the value is
   in git history, so the password itself has to change.
2. Confirm the keep/drop split above before any schema work.
3. Create the Supabase project at that point, not before. The free
   organisation is already at its two active projects, and an idle third buys
   nothing.
4. Write the schema with RLS policies from the first migration, not added
   afterwards.

## Explicitly deferred

No Supabase project has been created. No schema has been written. Nothing in
the mobile app depends on this: identity derivation, the vault, the browser,
autofill and tracker blocking are all local by design, and that locality is the
architecture working rather than a gap to be filled. The less server-side state
this product holds, the less exists to leak or be compelled.
