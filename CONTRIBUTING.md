# Contributing to Shadow

Thanks for helping. Small, reviewable changes are easier to land than large ones.

## Before you start

1. Fork the repository and clone your fork.
2. Copy `env.example` to `.env`. Do not put real secrets in git.
3. Read [docs/running-locally.md](docs/running-locally.md) for the mobile/Android path and [docs/README.md](docs/README.md) for the overall layout.

## Ground rules

- **No secrets.** Keypairs, `.env` files, Atlas URIs, and API keys must stay local. `*.json` is denied by default in `.gitignore` because a Solana keypair is a bare JSON array.
- **Keep PRs focused.** One concern per pull request when you can.
- **Do not rewrite history** on `main`.

## Commit messages

This repo often uses Greek-mythology themed subjects (see `.gitmessage`). Clear conventional messages (`fix:`, `docs:`, `chore:`) are also fine, especially for first-time contributions. Prefer *why* over a file list.

## What to test

- Rust backend: `cargo fmt --all -- --check`, `cargo clippy -p shadow-backend --all-targets`, `cargo test -p shadow-backend`
- Flutter mobile: `cd mobile && flutter analyze && flutter test`
- Mail worker: `cd services/mail-worker && npm ci && npx tsc --noEmit`

You do not need every job green locally. CI runs the mobile, Android, iOS, backend, and mail-worker paths.

## Pull requests

Open against `main`. Describe the problem, the change, and how you checked it. Link related issues if they exist.
