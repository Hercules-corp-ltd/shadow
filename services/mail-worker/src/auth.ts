/**
 * Proving you own a mailbox, without an account.
 *
 * There is no login here and there is deliberately no bearer token. A token
 * that covers two mailboxes *is* the link between them, and it is stealable
 * from the device besides. Every request carries its own Ed25519 signature
 * from that mailbox's own key, so the protocol contains no identifier that
 * spans two mailboxes at all.
 *
 * What this does not fix: the operator still sees which mailbox was polled,
 * from which IP, at what moment. That is an OHTTP problem and it needs a
 * genuinely independent relay operator to mean anything — a relay we ran
 * ourselves would be theatre. Say so rather than implying otherwise.
 */

const LOCAL_PART_CONTEXT = 'shadow.mail.localpart.v1';
const LOCAL_PART_LENGTH = 20;
const BASE32 = 'abcdefghijklmnopqrstuvwxyz234567';

/**
 * Every length a derived mask address has ever been truncated to.
 *
 * Append here and never edit — a mask that used to be issued is still out in
 * the world on somebody's account, and its row may not exist yet. This array
 * is the whole disjointness argument: a name a person can claim is refused if
 * its length appears here, so no claim can ever land on a mask address.
 */
export const MASK_LOCAL_PART_LENGTHS: readonly number[] = [LOCAL_PART_LENGTH];

/** Bounds on a name a person types. Deliberately excludes every mask length. */
export const CLAIM_MIN_LENGTH = 5;
export const CLAIM_MAX_LENGTH = 19;

/**
 * Names the mail service keeps for itself.
 *
 * `postmaster` and `abuse` are not optional politeness: RFC 2142 requires a
 * domain to answer them, and a provider that cannot reach either one starts
 * treating the whole domain as unattended. The rest are the addresses people
 * assume belong to whoever runs the service, which is exactly why handing one
 * to a stranger is a phishing primitive.
 *
 * Anything shorter than CLAIM_MIN_LENGTH — root, mail, help, info, team — is
 * already unclaimable on length and is left out rather than listed twice.
 */
export const RESERVED_NAMES: ReadonlySet<string> = new Set([
  'abuse',
  'administrator',
  'billing',
  'contact',
  'hostmaster',
  'mailer',
  'noreply',
  'postmaster',
  'privacy',
  'security',
  'shadow',
  'staff',
  'support',
  'webmaster',
]);

/** True for a string shaped like a derived mask address. */
export function isMaskShaped(localPart: string): boolean {
  return (
    MASK_LOCAL_PART_LENGTHS.includes(localPart.length) &&
    /^[a-z2-7]+$/.test(localPart)
  );
}

/**
 * Whether a person is allowed to claim this name.
 *
 * The alphabet is the mask alphabet rather than the wider `[a-z0-9-]` a
 * username field would allow, and that is a deliberate cost. It removes every
 * confusable pair at a stroke — no `0`/`o`, no `1`/`l`, no uppercase, and no
 * hyphen, so `alice-support` cannot exist alongside `alicesupport`. On an
 * address a person hands out and other people type from memory, impersonation
 * is the harm that matters more than expressiveness.
 *
 * What it costs, said plainly: nobody can claim `alice1` or `bob-smith`.
 */
export function isClaimableName(name: string): boolean {
  if (name.length < CLAIM_MIN_LENGTH || name.length > CLAIM_MAX_LENGTH) {
    return false;
  }
  // Byte-identical to its own canonical form. Never folded: deliver()
  // lowercases the recipient before it looks a row up, so a row stored with
  // any uppercase in it could never be reached by mail at all.
  if (!/^[a-z2-7]+$/.test(name)) return false;
  // Not redundant with the bounds above. At today's mask length of 20 the
  // bounds already exclude every mask, and this line never fires. It is what
  // holds the rule if a future truncation lands *inside* 5..19 — the one way
  // the disjointness argument could quietly stop being true.
  if (MASK_LOCAL_PART_LENGTHS.includes(name.length)) return false;
  return !RESERVED_NAMES.has(name);
}

/** Freshness window on a signed request, in seconds, either direction. */
export const CLOCK_SKEW_SECONDS = 60;

export function base32Encode(bytes: Uint8Array): string {
  let out = '';
  let acc = 0;
  let bits = 0;
  for (const byte of bytes) {
    acc = (acc << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += BASE32[(acc >> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += BASE32[(acc << (5 - bits)) & 31];
  return out;
}

export function fromBase64(value: string): Uint8Array | null {
  try {
    const binary = atob(value);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

export function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/**
 * The address is a hash of the key, so the claim checks itself.
 *
 * This is what removes the account. The server does not need to know who is
 * registering, or to have met them before — only that whoever is asking can
 * produce a key that hashes to the address they are asking for.
 */
export async function localPartMatches(
  localPart: string,
  ed25519Pub: Uint8Array,
): Promise<boolean> {
  if (!/^[a-z2-7]{20}$/.test(localPart)) return false;

  const context = new TextEncoder().encode(LOCAL_PART_CONTEXT);
  const input = new Uint8Array(context.length + ed25519Pub.length);
  input.set(context, 0);
  input.set(ed25519Pub, context.length);

  const digest = new Uint8Array(
    await crypto.subtle.digest('SHA-256', input as BufferSource),
  );
  return base32Encode(digest).slice(0, LOCAL_PART_LENGTH) === localPart;
}

export async function verifySignature(
  ed25519Pub: Uint8Array,
  transcript: string,
  signature: Uint8Array,
): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      ed25519Pub as BufferSource,
      { name: 'Ed25519' },
      false,
      ['verify'],
    );
    return await crypto.subtle.verify(
      { name: 'Ed25519' },
      key,
      signature as BufferSource,
      new TextEncoder().encode(transcript) as BufferSource,
    );
  } catch {
    return false;
  }
}

/**
 * Rejects a stale or future-dated request.
 *
 * The timestamp is inside the signed transcript, so this bounds replay
 * without the server storing a nonce table — which would itself be a record
 * of when each mailbox was active.
 */
export function timestampIsFresh(timestamp: number, nowSeconds: number): boolean {
  if (!Number.isFinite(timestamp)) return false;
  return Math.abs(nowSeconds - timestamp) <= CLOCK_SKEW_SECONDS;
}

/**
 * Hashcash over the address being claimed.
 *
 * This is what replaces an identity gate. Requiring a wallet signature would
 * have handed the operator a map from a publicly cross-referenceable,
 * KYC-linkable on-chain identity to the user's complete list of accounts —
 * the exact harm this product exists to prevent — while stopping nobody,
 * because keypairs are free and an abuser simply makes one per registration.
 *
 * Work costs the same whoever you are, and reveals nothing about you.
 */
export async function powIsValid(
  localPart: string,
  nonce: string,
  bits: number,
): Promise<boolean> {
  if (nonce.length > 64) return false;

  const digest = new Uint8Array(
    await crypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(
        `shadow-mail-pow/v1|${localPart}|${nonce}`,
      ) as BufferSource,
    ),
  );

  let remaining = bits;
  for (const byte of digest) {
    if (remaining <= 0) return true;
    if (remaining >= 8) {
      if (byte !== 0) return false;
      remaining -= 8;
    } else {
      return byte >>> (8 - remaining) === 0;
    }
  }
  return remaining <= 0;
}

/** Days since the epoch. Bucketed on purpose — see schema.sql. */
export function today(nowMs: number): number {
  return Math.floor(nowMs / 86_400_000);
}
