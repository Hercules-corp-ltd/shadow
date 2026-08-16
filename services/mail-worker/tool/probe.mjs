#!/usr/bin/env node
// End-to-end proof for the mail Worker, with no domain and no DNS.
//
//   node tool/probe.mjs [base-url]
//
// Registers a mailbox, feeds raw MIME through the same delivery path
// Cloudflare's email() handler uses, polls it back, and opens the seal.
// Then it checks the refusals that matter: an unregistered address, a
// rebind attempt with a different key, a forged signature, and the
// provisional cap.
//
// It is also the reference for the Dart client. Anything here that the app
// implements differently is a bug in one of the two, and this file is short
// enough to diff against by eye.

const BASE = process.argv[2] ?? 'http://127.0.0.1:8787';
const POW_BITS = 8; // matches env.dev

const b64 = (bytes) => Buffer.from(bytes).toString('base64');
const enc = new TextEncoder();

let failures = 0;
function check(label, ok, detail = '') {
  console.log(`${ok ? '  ok  ' : ' FAIL '} ${label}${detail ? ` — ${detail}` : ''}`);
  if (!ok) failures++;
}

async function post(path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* empty */
  }
  return { status: res.status, json };
}

const BASE32 = 'abcdefghijklmnopqrstuvwxyz234567';
function base32(bytes) {
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

/** A mailbox, as the client derives one. */
async function makeMailbox() {
  const signing = await crypto.subtle.generateKey({ name: 'Ed25519' }, true, [
    'sign',
    'verify',
  ]);
  const sealing = await crypto.subtle.generateKey({ name: 'X25519' }, true, [
    'deriveBits',
  ]);

  const edPub = new Uint8Array(
    await crypto.subtle.exportKey('raw', signing.publicKey),
  );
  const xPub = new Uint8Array(
    await crypto.subtle.exportKey('raw', sealing.publicKey),
  );

  const context = enc.encode('shadow.mail.localpart.v1');
  const input = new Uint8Array(context.length + edPub.length);
  input.set(context, 0);
  input.set(edPub, context.length);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', input));
  const localPart = base32(digest).slice(0, 20);

  const sign = async (transcript) =>
    new Uint8Array(
      await crypto.subtle.sign(
        { name: 'Ed25519' },
        signing.privateKey,
        enc.encode(transcript),
      ),
    );

  return { localPart, edPub, xPub, sign, sealingPrivate: sealing.privateKey };
}

/** Hashcash over the address being claimed. */
async function mine(localPart, bits) {
  for (let n = 0; ; n++) {
    const digest = new Uint8Array(
      await crypto.subtle.digest(
        'SHA-256',
        enc.encode(`shadow-mail-pow/v1|${localPart}|${n}`),
      ),
    );
    let remaining = bits;
    let ok = true;
    for (const byte of digest) {
      if (remaining <= 0) break;
      if (remaining >= 8) {
        if (byte !== 0) {
          ok = false;
          break;
        }
        remaining -= 8;
      } else {
        ok = byte >>> (8 - remaining) === 0;
        break;
      }
    }
    if (ok) return String(n);
  }
}

/** The client half of the seal. Mirrors src/seal.ts exactly. */
async function unseal(envelope, sealingPrivate, myXPub) {
  const epk = envelope.subarray(0, 32);
  const nonce = envelope.subarray(32, 44);
  const ciphertext = envelope.subarray(44);

  const ephemeral = await crypto.subtle.importKey(
    'raw',
    epk,
    { name: 'X25519' },
    false,
    [],
  );
  const shared = await crypto.subtle.deriveBits(
    { name: 'X25519', public: ephemeral },
    sealingPrivate,
    256,
  );

  const info = new Uint8Array(epk.length + myXPub.length);
  info.set(epk, 0);
  info.set(myXPub, epk.length);

  const base = await crypto.subtle.importKey('raw', shared, 'HKDF', false, [
    'deriveKey',
  ]);
  const key = await crypto.subtle.deriveKey(
    {
      name: 'HKDF',
      hash: 'SHA-256',
      salt: enc.encode('shadow.mail.seal.v1'),
      info,
    },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt'],
  );

  const padded = new Uint8Array(
    await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: nonce, additionalData: epk },
      key,
      ciphertext,
    ),
  );
  const length = new DataView(padded.buffer).getUint32(0, false);
  return new TextDecoder().decode(padded.subarray(4, 4 + length));
}

async function register(mb) {
  const timestamp = Math.floor(Date.now() / 1000);
  const pow = await mine(mb.localPart, POW_BITS);
  const signature = await mb.sign(
    `mail-register/v1|${mb.localPart}|${b64(mb.xPub)}|${timestamp}`,
  );
  return post('/mail/register', {
    local_part: mb.localPart,
    ed25519_pub: b64(mb.edPub),
    x25519_pub: b64(mb.xPub),
    pow,
    timestamp,
    signature: b64(signature),
  });
}

async function poll(mb, cursor = 0) {
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = await mb.sign(
    `mail-poll/v1|${mb.localPart}|${cursor}|${timestamp}`,
  );
  return post('/mail/poll', {
    local_part: mb.localPart,
    cursor,
    timestamp,
    signature: b64(signature),
  });
}

const MESSAGE = [
  'From: Twitter <verify@twitter.com>',
  'Subject: 483920 is your Twitter confirmation code',
  'Content-Type: text/plain; charset=utf-8',
  '',
  'Your code is 483920. It expires in 10 minutes.',
].join('\r\n');

async function main() {
  console.log(`probing ${BASE}\n`);

  console.log('the happy path');
  const alice = await makeMailbox();
  const registered = await register(alice);
  check('register accepts a self-certifying address', registered.status === 200);
  check(
    'the receipt echoes the sealing key the client sent',
    registered.json?.x25519_pub === b64(alice.xPub),
  );

  const delivered = await post('/_dev/inbound', {
    to: `${alice.localPart}@mail.shadow.test`,
    raw: MESSAGE,
  });
  check('inbound mail for a registered address is accepted', delivered.status === 200);

  const polled = await poll(alice);
  check('poll returns the message', polled.json?.messages?.length === 1);

  if (polled.json?.messages?.length) {
    const envelope = Buffer.from(polled.json.messages[0].sealed, 'base64');
    const opened = await unseal(
      new Uint8Array(envelope),
      alice.sealingPrivate,
      alice.xPub,
    );
    check('the seal opens to exactly what was sent', opened === MESSAGE);
    check(
      'the code survives the round trip',
      /483920/.test(opened),
      opened.split('\r\n')[1],
    );
    check(
      'the stored envelope is padded to a bucket',
      [4096, 16384, 65536].includes(envelope.length - 32 - 12 - 16),
      `${envelope.length} bytes on the wire`,
    );
  }

  console.log('\nrefusals');
  const stranger = await makeMailbox();
  const toNobody = await post('/_dev/inbound', {
    to: `${stranger.localPart}@mail.shadow.test`,
    raw: MESSAGE,
  });
  check(
    'mail to an unregistered address is rejected, not stored',
    toNobody.json?.rejected === 'No such recipient',
  );

  const rebind = await makeMailbox();
  const timestamp = Math.floor(Date.now() / 1000);
  const stolen = await post('/mail/register', {
    local_part: alice.localPart,
    ed25519_pub: b64(rebind.edPub),
    x25519_pub: b64(rebind.xPub),
    pow: await mine(alice.localPart, POW_BITS),
    timestamp,
    signature: b64(
      await rebind.sign(
        `mail-register/v1|${alice.localPart}|${b64(rebind.xPub)}|${timestamp}`,
      ),
    ),
  });
  check(
    "someone else's key cannot claim an address that is not its hash",
    stolen.status === 400,
    `status ${stolen.status}`,
  );

  const noPow = await makeMailbox();
  const ts2 = Math.floor(Date.now() / 1000);
  const unmined = await post('/mail/register', {
    local_part: noPow.localPart,
    ed25519_pub: b64(noPow.edPub),
    x25519_pub: b64(noPow.xPub),
    pow: 'not-mined',
    timestamp: ts2,
    signature: b64(
      await noPow.sign(
        `mail-register/v1|${noPow.localPart}|${b64(noPow.xPub)}|${ts2}`,
      ),
    ),
  });
  check('registration without the work is refused', unmined.status === 402);

  const forged = await post('/mail/poll', {
    local_part: alice.localPart,
    cursor: 0,
    timestamp: Math.floor(Date.now() / 1000),
    signature: b64(new Uint8Array(64)),
  });
  check('a forged signature cannot read a mailbox', forged.status === 401);

  const stale = await post('/mail/poll', {
    local_part: alice.localPart,
    cursor: 0,
    timestamp: Math.floor(Date.now() / 1000) - 600,
    signature: b64(await alice.sign(`mail-poll/v1|${alice.localPart}|0|0`)),
  });
  check('a stale request is refused', stale.status === 400);

  console.log('\nprovisional cap');
  const idle = await makeMailbox();
  await register(idle);
  const results = [];
  for (let i = 0; i < 4; i++) {
    const res = await post('/_dev/inbound', {
      to: `${idle.localPart}@mail.shadow.test`,
      raw: MESSAGE,
    });
    results.push(res.json?.ok === true);
  }
  check(
    'a never-polled mailbox accepts 3 and then stops',
    results.join(',') === 'true,true,true,false',
    results.join(','),
  );
  await poll(idle);
  const afterPoll = await post('/_dev/inbound', {
    to: `${idle.localPart}@mail.shadow.test`,
    raw: MESSAGE,
  });
  check('polling proves an owner and lifts the cap', afterPoll.json?.ok === true);

  console.log(
    failures === 0
      ? '\nall checks passed'
      : `\n${failures} check(s) failed`,
  );
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
