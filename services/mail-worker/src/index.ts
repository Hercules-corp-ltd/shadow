import {
  fromBase64,
  isClaimableName,
  isMaskShaped,
  localPartMatches,
  powIsValid,
  timestampIsFresh,
  toBase64,
  today,
  verifySignature,
} from './auth';
import { MAX_SEALED, seal } from './seal';

export interface Env {
  DB: D1Database;
  SEALED: R2Bucket;
  ALIAS_DOMAIN: string;
  RETENTION_DAYS: string;
  POW_BITS: string;
  PROVISIONAL_MESSAGE_CAP: string;
  MESSAGE_CAP: string;
  CLAIM_POW_BITS: string;
  DEV_INBOUND?: string;
}

interface MailboxRow {
  local_part: string;
  ed25519_pub: string;
  x25519_pub: string;
  polled: number;
  seq: number;
  received: number;
  retired: number;
}

/**
 * Every response is this shape and this shape only.
 *
 * No field ever says why a signature failed, whether a mailbox exists but is
 * retired, or how close to a cap it is. A rich error is an oracle, and the
 * only party who benefits from one here is someone probing addresses they do
 * not own.
 */
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      // No CORS. The only client is the app, and a browser-reachable mail
      // endpoint is a cross-site request forgery surface for no benefit.
    },
  });
}

/**
 * Reads the body of a signed request.
 *
 * The local part is in the body and never in the path or the query, because
 * URLs are logged by every CDN, proxy and error tracker in the chain —
 * including ones we do not run and cannot purge.
 */
async function readSigned(
  request: Request,
): Promise<{ localPart: string; timestamp: number; signature: Uint8Array; body: Record<string, unknown> } | null> {
  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return null;
  }

  const localPart = body.local_part;
  const timestamp = body.timestamp;
  const signature = typeof body.signature === 'string' ? fromBase64(body.signature) : null;

  if (typeof localPart !== 'string' || typeof timestamp !== 'number' || !signature) {
    return null;
  }
  return { localPart, timestamp, signature, body };
}

/**
 * What to answer when there is no such row.
 *
 * A mask address is a 100-bit preimage of a key, so telling an
 * unauthenticated caller that one does not exist reveals nothing they could
 * not have computed for themselves. A claimed name is a word somebody chose,
 * and the same answer would be a free directory of every name that is held —
 * no signature, no work, no cost. So for a claimed name, "no such row" and
 * "your signature is wrong" have to be indistinguishable.
 *
 * This is why the fence lives here rather than in one handler: poll, retire
 * and probe all take a local part, and leaving any one of them answering
 * honestly would hand back everything the other two withhold.
 */
function missingRowStatus(localPart: string): number {
  return isMaskShaped(localPart) ? 404 : 401;
}

async function loadMailbox(env: Env, localPart: string): Promise<MailboxRow | null> {
  const row = await env.DB.prepare(
    'SELECT local_part, ed25519_pub, x25519_pub, polled, seq, received, retired FROM mailbox WHERE local_part = ?',
  )
    .bind(localPart)
    .first<MailboxRow>();
  return row ?? null;
}

/**
 * The claimed row belonging to a key, if it has one.
 *
 * `length(local_part) <> 20` is the same disjointness rule as
 * `MASK_LOCAL_PART_LENGTHS`, restated in SQL because SQL cannot import it.
 * The two must be changed together, and the fuzz check in tool/probe.mjs is
 * what fails loudly if they ever drift apart.
 */
async function loadClaimedByKey(env: Env, edPubB64: string): Promise<MailboxRow | null> {
  const row = await env.DB.prepare(
    'SELECT local_part, ed25519_pub, x25519_pub, polled, seq, received, retired FROM mailbox WHERE ed25519_pub = ? AND length(local_part) <> 20',
  )
    .bind(edPubB64)
    .first<MailboxRow>();
  return row ?? null;
}

/**
 * Claims an address.
 *
 * Three gates, in this order: the address must be the hash of the key
 * presented, the request must be signed by that key, and the proof of work
 * must be there. None of them asks who is registering.
 */
async function handleRegister(request: Request, env: Env): Promise<Response> {
  const signed = await readSigned(request);
  if (!signed) return json({ ok: false }, 400);

  const { localPart, timestamp, signature, body } = signed;
  const edPub = typeof body.ed25519_pub === 'string' ? fromBase64(body.ed25519_pub) : null;
  const xPub = typeof body.x25519_pub === 'string' ? fromBase64(body.x25519_pub) : null;
  const powNonce = typeof body.pow === 'string' ? body.pow : null;

  if (!edPub || edPub.length !== 32 || !xPub || xPub.length !== 32 || powNonce === null) {
    return json({ ok: false }, 400);
  }
  if (!timestampIsFresh(timestamp, Math.floor(Date.now() / 1000))) {
    return json({ ok: false }, 400);
  }
  if (!(await localPartMatches(localPart, edPub))) {
    return json({ ok: false }, 400);
  }

  const transcript = `mail-register/v1|${localPart}|${toBase64(xPub)}|${timestamp}`;
  if (!(await verifySignature(edPub, transcript, signature))) {
    return json({ ok: false }, 401);
  }
  if (!(await powIsValid(localPart, powNonce, Number(env.POW_BITS)))) {
    return json({ ok: false }, 402);
  }

  const expires = today(Date.now()) + 365;
  const existing = await loadMailbox(env, localPart);

  if (existing) {
    // Idempotent for the same key, refused for a different one. Without the
    // refusal, anyone who learned an address could re-point it at their own
    // key and take delivery of the password resets that follow.
    if (existing.ed25519_pub !== toBase64(edPub)) return json({ ok: false }, 409);

    await env.DB.prepare(
      'UPDATE mailbox SET x25519_pub = ?, expires_day = ?, retired = 0 WHERE local_part = ?',
    )
      .bind(toBase64(xPub), expires, localPart)
      .run();
  } else {
    await env.DB.prepare(
      'INSERT INTO mailbox (local_part, ed25519_pub, x25519_pub, expires_day) VALUES (?, ?, ?, ?)',
    )
      .bind(localPart, toBase64(edPub), toBase64(xPub), expires)
      .run();
  }

  // A receipt the client re-checks before it fills the address into a form.
  // Without it, a substituted registration would silently eat the user's
  // mail forever and the account would be unrecoverable with no error.
  return json({ ok: true, local_part: localPart, x25519_pub: toBase64(xPub) });
}

async function handlePoll(request: Request, env: Env): Promise<Response> {
  const signed = await readSigned(request);
  if (!signed) return json({ ok: false }, 400);

  const { localPart, timestamp, signature, body } = signed;
  const cursor = typeof body.cursor === 'number' ? body.cursor : 0;

  if (!timestampIsFresh(timestamp, Math.floor(Date.now() / 1000))) {
    return json({ ok: false }, 400);
  }

  const mailbox = await loadMailbox(env, localPart);
  if (!mailbox) return json({ ok: false }, missingRowStatus(localPart));

  const edPub = fromBase64(mailbox.ed25519_pub);
  if (!edPub) return json({ ok: false }, missingRowStatus(localPart));

  const transcript = `mail-poll/v1|${localPart}|${cursor}|${timestamp}`;
  if (!(await verifySignature(edPub, transcript, signature))) {
    return json({ ok: false }, 401);
  }

  const rows = await env.DB.prepare(
    'SELECT seq, object_key FROM message WHERE local_part = ? AND seq > ? ORDER BY seq ASC LIMIT 20',
  )
    .bind(localPart, cursor)
    .all<{ seq: number; object_key: string }>();

  const messages: Array<{ seq: number; sealed: string }> = [];
  for (const row of rows.results ?? []) {
    const object = await env.SEALED.get(row.object_key);
    if (!object) continue;
    messages.push({
      seq: row.seq,
      sealed: toBase64(new Uint8Array(await object.arrayBuffer())),
    });
  }

  // Polling is what proves a mailbox has an owner, so it both lifts the
  // provisional cap and renews the registration. Activity is recorded as a
  // day bucket and a flag, never as a time.
  await env.DB.prepare(
    'UPDATE mailbox SET polled = 1, expires_day = ? WHERE local_part = ?',
  )
    .bind(today(Date.now()) + 365, localPart)
    .run();

  return json({ ok: true, messages, cursor: mailbox.seq });
}

/** Burns an address. The client bumps its own alias epoch separately. */
async function handleRetire(request: Request, env: Env): Promise<Response> {
  const signed = await readSigned(request);
  if (!signed) return json({ ok: false }, 400);

  const { localPart, timestamp, signature } = signed;
  if (!timestampIsFresh(timestamp, Math.floor(Date.now() / 1000))) {
    return json({ ok: false }, 400);
  }

  const mailbox = await loadMailbox(env, localPart);
  if (!mailbox) return json({ ok: false }, missingRowStatus(localPart));

  const edPub = fromBase64(mailbox.ed25519_pub);
  if (!edPub) return json({ ok: false }, missingRowStatus(localPart));

  const transcript = `mail-retire/v1|${localPart}|${timestamp}`;
  if (!(await verifySignature(edPub, transcript, signature))) {
    return json({ ok: false }, 401);
  }

  await env.DB.prepare('UPDATE mailbox SET retired = 1 WHERE local_part = ?')
    .bind(localPart)
    .run();
  return json({ ok: true });
}

/**
 * Answers "does this address exist and is it mine?" for a client rebuilding
 * lost state.
 *
 * Signed like everything else, so it proves nothing to anyone who does not
 * already hold the key — and therefore reveals nothing the asker could not
 * already compute for themselves.
 */
async function handleProbe(request: Request, env: Env): Promise<Response> {
  const signed = await readSigned(request);
  if (!signed) return json({ ok: false }, 400);

  const { localPart, timestamp, signature } = signed;
  if (!timestampIsFresh(timestamp, Math.floor(Date.now() / 1000))) {
    return json({ ok: false }, 400);
  }

  // Mask addresses only. The reasoning above — that the answer reveals
  // nothing the asker could not compute — holds because a mask is a 100-bit
  // preimage. It is simply false for a name a person chose, and rather than
  // weaken probe for the masks that depend on it, claimed names are refused
  // the endpoint outright. Their state comes from /mail/claimed, which
  // verifies a signature before it answers anything.
  if (!isMaskShaped(localPart)) return json({ ok: false }, 400);

  const mailbox = await loadMailbox(env, localPart);
  if (!mailbox) return json({ ok: true, exists: false });

  const edPub = fromBase64(mailbox.ed25519_pub);
  if (!edPub) return json({ ok: true, exists: false });

  const transcript = `mail-probe/v1|${localPart}|${timestamp}`;
  if (!(await verifySignature(edPub, transcript, signature))) {
    return json({ ok: false }, 401);
  }

  return json({
    ok: true,
    exists: true,
    retired: mailbox.retired === 1,
    cursor: mailbox.seq,
  });
}

/**
 * Claims a name a person chose.
 *
 * ## How this differs from register, and why the difference is the whole risk
 *
 * A mask address certifies itself: the local part is a hash of the key, so
 * `localPartMatches` alone decides whether a claim is legitimate and no two
 * people can want the same one. A name someone typed certifies nothing. That
 * removes the check register leans on, so this handler has to replace it with
 * three separate rules:
 *
 *  1. The name must be *incapable* of being a mask — `isClaimableName`
 *     refuses every length a mask has ever used. Without this, anyone who
 *     saw a derived address before it was registered could claim it here and
 *     take delivery of the password resets that follow. Shadow shows
 *     unregistered addresses in the UI, so "before it was registered" is a
 *     real window, not a theoretical one.
 *  2. The signed transcript carries the key explicitly. For a mask the local
 *     part implies the key, so `mail-register/v1` can leave it out; here it
 *     cannot, or one signature would be valid for every name at once.
 *  3. One name per identity, enforced by a unique index rather than by a
 *     read-then-write. Two devices holding the same phrase racing for the
 *     same name is the ordinary case, not the exotic one.
 */
async function handleClaim(request: Request, env: Env): Promise<Response> {
  const signed = await readSigned(request);
  if (!signed) return json({ ok: false }, 400);

  const { localPart, timestamp, signature, body } = signed;
  const edPub = typeof body.ed25519_pub === 'string' ? fromBase64(body.ed25519_pub) : null;
  const xPub = typeof body.x25519_pub === 'string' ? fromBase64(body.x25519_pub) : null;
  const powNonce = typeof body.pow === 'string' ? body.pow : null;

  // Every stateless gate runs before the first database touch, so a rejected
  // shape never costs a lookup and never becomes a cheaper way to ask
  // whether a name is held than paying for the work below.
  if (!edPub || edPub.length !== 32 || !xPub || xPub.length !== 32 || powNonce === null) {
    return json({ ok: false }, 400);
  }
  if (!timestampIsFresh(timestamp, Math.floor(Date.now() / 1000))) {
    return json({ ok: false }, 400);
  }
  if (!isClaimableName(localPart)) return json({ ok: false }, 400);

  const transcript =
    `mail-claim/v1|${localPart}|${toBase64(edPub)}|${toBase64(xPub)}|${timestamp}`;
  if (!(await verifySignature(edPub, transcript, signature))) {
    return json({ ok: false }, 401);
  }
  if (!(await powIsValid(localPart, powNonce, Number(env.CLAIM_POW_BITS)))) {
    return json({ ok: false }, 402);
  }

  const expires = today(Date.now()) + 365;

  // No conflict target, so this covers both the primary key and the unique
  // index on the claimed key. Whoever wins a race is decided by the database.
  //
  // The tempting repair when this returns no row — ON CONFLICT DO UPDATE — is
  // the rebind that every takeover in this file exists to prevent. It is not
  // needed: the read-back below distinguishes all three outcomes.
  await env.DB.prepare(
    'INSERT INTO mailbox (local_part, ed25519_pub, x25519_pub, expires_day) VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING',
  )
    .bind(localPart, toBase64(edPub), toBase64(xPub), expires)
    .run();

  const byName = await loadMailbox(env, localPart);
  if (byName) {
    // Someone else holds it, or it is a mask row that must never be reachable
    // from here even if a future truncation makes one claim-shaped.
    if (byName.ed25519_pub !== toBase64(edPub)) return json({ ok: false }, 409);
    if (isMaskShaped(byName.local_part)) return json({ ok: false }, 409);

    // Ours. Idempotent: un-retire and renew, but never rebind either key. The
    // sealing key is derived from the same branch key at the same epoch, so a
    // claimed row has no legitimate reason for it to change, and the receipt
    // below echoes what is stored rather than what was presented.
    await env.DB.prepare(
      'UPDATE mailbox SET expires_day = ?, retired = 0 WHERE local_part = ?',
    )
      .bind(expires, localPart)
      .run();

    return json({
      ok: true,
      local_part: byName.local_part,
      ed25519_pub: byName.ed25519_pub,
      x25519_pub: byName.x25519_pub,
    });
  }

  // The name is free but the insert still did nothing, so the conflict was on
  // the key: this identity already holds a different name. Answer with the
  // one it holds. This is what makes a reinstall recoverable — and what stops
  // a second claim from quietly becoming a second name.
  const held = await loadClaimedByKey(env, toBase64(edPub));
  if (held) {
    return json({
      ok: true,
      local_part: held.local_part,
      ed25519_pub: held.ed25519_pub,
      x25519_pub: held.x25519_pub,
    });
  }

  // Neither name nor key is present and the insert did nothing. Nothing true
  // can be said about what is held, so say nothing.
  return json({ ok: false }, 409);
}

/**
 * Answers "what name does this key hold?".
 *
 * Not an oracle: the transcript is signed by the key being asked about, so
 * only whoever holds its private half can ask, and the answer is a thing they
 * already own. It exists because a claimed name is the one piece of state the
 * recovery phrase cannot rebuild — the phrase regenerates the key, but no
 * amount of derivation recovers a word a person typed.
 *
 * Without it the reinstall path is a trap: the only other way to discover a
 * name is to attempt a claim, and attempting a claim when you hold nothing
 * takes the name you guessed with.
 */
async function handleClaimed(request: Request, env: Env): Promise<Response> {
  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return json({ ok: false }, 400);
  }

  const edPub = typeof body.ed25519_pub === 'string' ? fromBase64(body.ed25519_pub) : null;
  const timestamp = typeof body.timestamp === 'number' ? body.timestamp : null;
  const signature = typeof body.signature === 'string' ? fromBase64(body.signature) : null;

  if (!edPub || edPub.length !== 32 || timestamp === null || !signature) {
    return json({ ok: false }, 400);
  }
  if (!timestampIsFresh(timestamp, Math.floor(Date.now() / 1000))) {
    return json({ ok: false }, 400);
  }

  const transcript = `mail-claimed/v1|${toBase64(edPub)}|${timestamp}`;
  if (!(await verifySignature(edPub, transcript, signature))) {
    return json({ ok: false }, 401);
  }

  const held = await loadClaimedByKey(env, toBase64(edPub));
  if (!held) return json({ ok: true, claimed: false });

  return json({
    ok: true,
    claimed: true,
    local_part: held.local_part,
    x25519_pub: held.x25519_pub,
    retired: held.retired === 1,
  });
}

/**
 * The delivery path, shared by real inbound mail and the dev simulator.
 *
 * Returns an SMTP-shaped refusal reason, or null on acceptance.
 */
async function deliver(
  env: Env,
  recipient: string,
  raw: Uint8Array,
): Promise<string | null> {
  const localPart = recipient.split('@')[0]?.toLowerCase() ?? '';
  const mailbox = await loadMailbox(env, localPart);

  // Rejecting unknown addresses is what stops the domain being classified as
  // a catch-all — and "accept-all" gets a domain marked risky by every
  // validator regardless of its reputation, which would block signups even
  // with a spotless record. It also bounds storage.
  if (!mailbox || mailbox.retired === 1) return 'No such recipient';

  if (mailbox.received >= Number(env.MESSAGE_CAP)) return 'Mailbox full';
  if (
    mailbox.polled === 0 &&
    mailbox.received >= Number(env.PROVISIONAL_MESSAGE_CAP)
  ) {
    return 'Mailbox not yet in use';
  }
  if (raw.length > MAX_SEALED) return 'Message too large';

  const xPub = fromBase64(mailbox.x25519_pub);
  if (!xPub) return 'Mailbox unavailable';

  const envelope = await seal(raw, xPub);
  if (!envelope) return 'Message too large';

  const seq = mailbox.seq + 1;
  const objectKey = crypto.randomUUID();
  await env.SEALED.put(objectKey, envelope as BufferSource);

  await env.DB.batch([
    env.DB.prepare(
      'INSERT INTO message (local_part, seq, object_key, padded_size, expires_day) VALUES (?, ?, ?, ?, ?)',
    ).bind(
      localPart,
      seq,
      objectKey,
      envelope.length,
      today(Date.now()) + Number(env.RETENTION_DAYS),
    ),
    env.DB.prepare(
      'UPDATE mailbox SET seq = ?, received = received + 1 WHERE local_part = ?',
    ).bind(seq, localPart),
  ]);

  return null;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') return json({ ok: false }, 405);
    const path = new URL(request.url).pathname;

    switch (path) {
      case '/mail/register':
        return handleRegister(request, env);
      case '/mail/claim':
        return handleClaim(request, env);
      case '/mail/claimed':
        return handleClaimed(request, env);
      case '/mail/poll':
        return handlePoll(request, env);
      case '/mail/retire':
        return handleRetire(request, env);
      case '/mail/probe':
        return handleProbe(request, env);
      case '/_dev/inbound': {
        // Feeds raw MIME through the exact path Cloudflare's email handler
        // uses, so the whole chain is provable before a domain exists. Absent
        // from production vars; if this flag is ever set in production it is
        // a configuration mistake, not a feature.
        if (env.DEV_INBOUND !== '1') return json({ ok: false }, 404);
        const body = (await request.json()) as { to?: string; raw?: string };
        if (!body.to || typeof body.raw !== 'string') return json({ ok: false }, 400);
        const reason = await deliver(
          env,
          body.to,
          new TextEncoder().encode(body.raw),
        );
        return reason === null
          ? json({ ok: true })
          : json({ ok: false, rejected: reason });
      }
      default:
        return json({ ok: false }, 404);
    }
  },

  /**
   * Cloudflare Email Routing calls this for every message the catch-all
   * matches.
   *
   * Rejecting in-session with `setReject` rather than accepting and bouncing
   * matters: a bounce we generate is backscatter, aimed at whatever address
   * the sender claimed, which is how a mail service becomes an amplifier.
   */
  async email(message: ForwardableEmailMessage, env: Env): Promise<void> {
    const raw = new Uint8Array(
      await new Response(message.raw).arrayBuffer(),
    );
    const reason = await deliver(env, message.to, raw);
    if (reason !== null) message.setReject(reason);
  },
};
