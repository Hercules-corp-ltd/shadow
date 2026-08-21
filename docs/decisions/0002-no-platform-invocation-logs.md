# 2. No platform invocation logs on the mail worker

**Status:** accepted
**Date:** 2026-08-01
**Applies when:** changing `services/mail-worker/wrangler.toml` observability.

## Decision

Cloudflare observability stays off for the mail worker. Inbound aliases must not produce invocation logs that record who polled, when, or from where.

## Why

The worker's job is to receive sealed mail and forget it. An invocation log is not "our" log — it is platform telemetry that survives a subpoena regardless of what the Worker chooses to write. Turning observability on would make "we do not log it" a claim about application code only.

There is also no outbound path, and there must never be one.

## Consequences

- `[observability] enabled = false` in `wrangler.toml` is load-bearing, not a default to flip for debugging in production.
- Local `wrangler dev` debugging is fine; production telemetry is not.
