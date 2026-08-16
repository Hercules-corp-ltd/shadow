-- Shadow mail receiver.
--
-- What is NOT here is the design.
--
--   * No IP address, at registration or poll. Used in memory for rate
--     limiting and then dropped.
--   * No sender. The From: header goes inside the sealed plaintext where
--     only the device can read it — the code UI needs it, so it is sealed
--     rather than stored in a column the storage layer could lie about.
--   * No subject, no Message-ID, no headers of any kind.
--   * No exact timestamps. Days, bucketed, and only where a TTL needs them.
--   * No global auto-increment. A shared sequence hands an operator
--     co-registration order for free, which is a linkage channel that costs
--     nothing to remove and everything to leave in.
--
-- The sequence that does exist is per mailbox, because a cursor needs an
-- order. It says how many messages this mailbox has had and nothing about
-- any other mailbox.

CREATE TABLE IF NOT EXISTS mailbox (
  -- base32(SHA-256("shadow.mail.localpart.v1" || ed25519_pub))[0..20].
  -- The address certifies itself: this column is a function of the next one.
  local_part      TEXT PRIMARY KEY,

  -- Bound on first registration and never rebound. Without that rule an
  -- attacker who learned an address could re-point it at their own key and
  -- silently take delivery of the password resets.
  ed25519_pub     TEXT NOT NULL,

  -- Mail is sealed to this. The server holds no private half of anything.
  x25519_pub      TEXT NOT NULL,

  -- Day bucket, not a timestamp. Renewed by polling.
  expires_day     INTEGER NOT NULL,

  -- 0 until the owner has fetched at least once. While 0 the mailbox accepts
  -- only PROVISIONAL_MESSAGE_CAP messages.
  polled          INTEGER NOT NULL DEFAULT 0,

  -- Per-mailbox message counter. Doubles as the poll cursor.
  seq             INTEGER NOT NULL DEFAULT 0,

  -- Lifetime message count, against MESSAGE_CAP.
  received        INTEGER NOT NULL DEFAULT 0,

  -- 1 when deliberately burned. Kept so an old address is recognised as
  -- retired rather than silently unknown.
  retired         INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS message (
  local_part      TEXT NOT NULL,

  -- Per-mailbox, monotonic. The client sends the highest it has seen and
  -- gets only what is newer, so the server never learns what was read.
  seq             INTEGER NOT NULL,

  -- Object key in R2. Random, not derived from anything about the message.
  object_key      TEXT NOT NULL,

  -- Padded size in bytes: 4096, 16384 or 65536.
  --
  -- Padding is not tidiness. A site that wants to deanonymise its users can
  -- pad the body of its own verification mail so the length encodes the
  -- account id, then join (local_part, size) against its own records. Fixed
  -- buckets remove the channel outright.
  padded_size     INTEGER NOT NULL,

  expires_day     INTEGER NOT NULL,

  PRIMARY KEY (local_part, seq)
);

CREATE INDEX IF NOT EXISTS message_expiry ON message (expires_day);
CREATE INDEX IF NOT EXISTS mailbox_expiry ON mailbox (expires_day);
