/**
 * Sealing inbound mail to a key only the recipient's phone holds.
 *
 * Shaped like libsodium's `crypto_box_seal`: a fresh ephemeral keypair per
 * message, so the sender is anonymous and the key is used exactly once.
 *
 * ## This is not end-to-end encryption, and must never be described as one
 *
 * SMTP delivers cleartext. By the time this function runs, the Worker has
 * already held the entire message — sender, subject, body, verification code
 * — in memory. Sealing means the operator cannot read it *again*: not from
 * storage, not under subpoena, not next year. It does not mean the operator
 * never saw it. The honest sentence is "we do not retain the ability to read
 * it", never "we cannot read it".
 *
 * ## Why AES-256-GCM rather than XChaCha20-Poly1305
 *
 * The Workers runtime exposes WebCrypto, which has no ChaCha of any kind.
 * The alternatives were bundling a JS cipher or using what both sides
 * implement natively. Since each message gets a fresh ephemeral key, the key
 * is used once and GCM's 96-bit nonce carries no reuse risk at all — the
 * usual reason to prefer an extended nonce does not apply here.
 */

const SEAL_SALT = 'shadow.mail.seal.v1';

export const EPK_BYTES = 32;
export const NONCE_BYTES = 12;
export const TAG_BYTES = 16;

/** 4 KB, 16 KB, 64 KB. Anything larger is refused before it reaches here. */
export const SIZE_BUCKETS = [4096, 16384, 65536] as const;
export const MAX_SEALED = SIZE_BUCKETS[SIZE_BUCKETS.length - 1];

export function bucketFor(length: number): number | null {
  for (const bucket of SIZE_BUCKETS) {
    if (length <= bucket) return bucket;
  }
  return null;
}

/**
 * Pads to the next bucket with a length prefix so the padding is removable.
 *
 * Layout: 4-byte big-endian real length, then the bytes, then zeros.
 */
export function pad(plaintext: Uint8Array): Uint8Array | null {
  const bucket = bucketFor(plaintext.length + 4);
  if (bucket === null) return null;

  const padded = new Uint8Array(bucket);
  new DataView(padded.buffer).setUint32(0, plaintext.length, false);
  padded.set(plaintext, 4);
  return padded;
}

export function unpad(padded: Uint8Array): Uint8Array {
  const length = new DataView(
    padded.buffer,
    padded.byteOffset,
    padded.byteLength,
  ).getUint32(0, false);
  return padded.subarray(4, 4 + length);
}

/**
 * Binds the derived key to both public keys.
 *
 * Without the recipient's key in the info, a ciphertext sealed to one
 * mailbox could be replayed at another and would still open. libsodium gets
 * the same property by deriving its nonce from blake2b(epk || rpk).
 */
async function sealKey(
  shared: ArrayBuffer,
  epk: Uint8Array,
  recipientPub: Uint8Array,
): Promise<CryptoKey> {
  const base = await crypto.subtle.importKey('raw', shared, 'HKDF', false, [
    'deriveKey',
  ]);
  const info = new Uint8Array(epk.length + recipientPub.length);
  info.set(epk, 0);
  info.set(recipientPub, epk.length);

  return crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: new TextEncoder().encode(SEAL_SALT),
      info,
    },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

/**
 * Wire format: `epk(32) || nonce(12) || ciphertext || tag(16)`.
 *
 * The ephemeral public key is also the AAD, so a ciphertext cannot be
 * re-labelled with someone else's ephemeral key.
 */
export async function seal(
  plaintext: Uint8Array,
  recipientX25519Pub: Uint8Array,
): Promise<Uint8Array | null> {
  const padded = pad(plaintext);
  if (padded === null) return null;

  const ephemeral = (await crypto.subtle.generateKey({ name: 'X25519' }, true, [
    'deriveBits',
  ])) as CryptoKeyPair;

  const recipient = await crypto.subtle.importKey(
    'raw',
    recipientX25519Pub as BufferSource,
    { name: 'X25519' },
    false,
    [],
  );

  // The runtime wants `public`; @cloudflare/workers-types declares the field
  // as `$public`, presumably to dodge the reserved word. Following the types
  // typechecks and then throws `Missing field "public"` at runtime, so the
  // cast is the correct way round and not laziness.
  const shared = await crypto.subtle.deriveBits(
    { name: 'X25519', public: recipient } as unknown as SubtleCryptoDeriveKeyAlgorithm,
    ephemeral.privateKey,
    256,
  );

  const epk = new Uint8Array(
    (await crypto.subtle.exportKey('raw', ephemeral.publicKey)) as ArrayBuffer,
  );
  const key = await sealKey(shared, epk, recipientX25519Pub);

  const nonce = crypto.getRandomValues(new Uint8Array(NONCE_BYTES));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: nonce, additionalData: epk },
      key,
      padded as BufferSource,
    ),
  );

  const envelope = new Uint8Array(
    EPK_BYTES + NONCE_BYTES + ciphertext.length,
  );
  envelope.set(epk, 0);
  envelope.set(nonce, EPK_BYTES);
  envelope.set(ciphertext, EPK_BYTES + NONCE_BYTES);
  return envelope;
}
