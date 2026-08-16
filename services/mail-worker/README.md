# Shadow mail receiver

Receives mail for the alias domain, seals it to a key only the recipient's
phone holds, and hands it over when that phone asks and can prove it.

There is no account here. An address is the hash of a public key, so claiming
one means producing a key that hashes to it and signing with the other half.
The server never learns who is asking, and there is no identifier in the
protocol that spans two mailboxes.

## What it is not

**Not end-to-end encrypted mail, and it must never be described as one.** SMTP
delivers cleartext, so this Worker holds the whole message — sender, subject,
body, code — in memory before it seals anything. What sealing buys is that the
operator cannot read it *again*: not from storage, not under subpoena, not
next year. The honest sentence is *"we do not retain the ability to read it"*.

Not an inbox, not a mail client, and **not a sender**. There is no outbound
path and there must never be one — sending is how alias services get abused
into phishing infrastructure, and refusing it is the single largest risk
reduction available.

## Running it locally

No domain and no Cloudflare account needed. `/_dev/inbound` feeds raw MIME
through the exact path Cloudflare's `email()` handler uses.

```bash
npm install
npx wrangler d1 execute shadow-mail --env dev --local --file schema.sql
npm run dev
```

Then, in another shell:

```bash
node tool/probe.mjs
```

`probe.mjs` registers a mailbox, delivers a message, polls it back, opens the
seal, and checks the refusals — unregistered recipient, rebinding an address
to a different key, forged signature, stale timestamp, and the provisional
cap. It is also the reference implementation of the wire format: anything the
Dart client does differently is a bug in one of the two.

## Going live

Everything below needs a domain and a Cloudflare account, and is deliberately
not automated — each step is a decision.

1. **Register a domain.** Boring and non-thematic. Nothing containing
   `temp`, `mask`, `alias`, `burner`, `private` or `shadow`. It should read
   like a small business that happens to run mail, because the alternative is
   being classified as disposable infrastructure by everyone who checks.
2. **Add it to Cloudflare** and let the nameservers propagate.
3. **Verify one destination address**, once, at account level. Email Routing
   requires at least one before any routing rule can be created. It is never
   used — nothing here forwards — but the rule cannot exist without it.
4. **Enable Email Routing**, then set the **catch-all** action to this Worker.
   Catch-all to a Worker is what makes the alias space unbounded: no per-address
   rules exist, so the 200-rules-per-domain cap never applies.
5. **Create the storage** and paste the returned id into `wrangler.toml`:
   ```bash
   npx wrangler d1 create shadow-mail
   npx wrangler r2 bucket create shadow-mail-sealed
   npx wrangler d1 execute shadow-mail --remote --file schema.sql
   npx wrangler deploy
   ```
6. **Publish DNS that makes the domain look run rather than parked:**
   SPF `v=spf1 -all` if it never sends, DMARC `v=DMARC1; p=reject`, and an
   A record with an actual page on it. A domain with no website is a
   documented disposable-domain signal.
7. **Put something at `abuse@` and `postmaster@`** that a person reads.
   Suspension works on a local part, so abuse can be handled without ever
   building a way to look up who owns one — keep it that way.

## Things that will bite

- **Cloudflare rejects inbound mail failing both SPF and DKIM**, honours the
  sender's DMARC policy, and rejects senders on RBLs. Fine for transactional
  mail, which is universally authenticated — but those rejections are
  invisible to us, so a code that never arrives may have been refused
  upstream with nothing to diagnose.
- **Unregistered recipients are rejected in-session with a 5xx**, never
  accepted and bounced. A bounce we generate is backscatter aimed at whatever
  address the sender claimed, which is how a mail service becomes an
  amplifier. It is also what stops the domain being classified *accept-all*,
  which would get signups blocked regardless of reputation.
- **Observability is off in `wrangler.toml` on purpose.** "We do not log it"
  is a claim about this code, not about the platform underneath it. Turning
  invocation logging on records request metadata for every poll, and a
  subpoena reaches whatever the platform kept.
- **Bindings are not inherited by named environments.** `[env.dev]` repeats
  the D1 and R2 blocks; leaving them out fails with a message about a missing
  database rather than anything mentioning inheritance.
- **`crypto.subtle.deriveBits` wants `public`** at runtime while
  `@cloudflare/workers-types` declares the field as `$public`. Following the
  types compiles and then throws.
