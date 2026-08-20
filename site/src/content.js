/**
 * What the page says, and where each thing sits on the loop.
 *
 * ## The conceit
 *
 * The app's home screen is a colonnade — an arched recess with a slot beneath
 * it and a row of gods in niches. The site is the same colonnade seen from the
 * side: you walk it, you pass each niche, and because a colonnade has no end
 * you arrive back at the door you came in by. That is the loop, and it is the
 * reason the loop exists — not decoration, but the shape of the idea.
 *
 * The last stage is the download and the first stage is the threshold, and they
 * sit next to each other across the wrap. Walking the whole colonnade puts you
 * at the door.
 *
 * ## The rule about copy
 *
 * Every claim on this page is one the app can support today. That constraint
 * cost us the best-sounding line on the page — mail *delivery* needs the worker
 * attached to a domain that receives mail, which has not shipped — so Hermes
 * talks about the address being derived and burnable, which is true and tested,
 * and says nothing about what arrives. The app's own onboarding was rewritten
 * to the same standard.
 */

/**
 * Scroll spent on the opening zoom, before any stage moves.
 *
 * Long enough that the phone is legible as a phone for the first third and the
 * arrival is not abrupt; short enough that somebody who came to press
 * "download" is not held hostage. One flick of a trackpad covers it.
 */
export const ZOOM_SPAN = 900;

/** Distance along the loop between one niche and the next, in pixels. */
export const STAGE_SPAN = 1100;

/**
 * The hero is no longer a stage.
 *
 * It used to be the first entry here, which meant the page opened on a stage
 * inside the portal and the phone had nothing to be. Now the hero is its own
 * DOM outside the opening, and these are the things you find *through* it.
 */
export const STAGES = [
  {
    // The first thing through the opening.
    //
    // It used to be a text slide, which wasted the arrival: you push through
    // a phone screen and land on a paragraph. The reference puts a composed
    // scene behind its card — a wall of the actual product — so the zoom
    // ends somewhere worth arriving at. This is ours: the app itself, three
    // real screens at three depths.
    id: 'canvas',
    navLabel: 'The app',
    kind: 'showcase',
    eyebrow: 'ONE PHRASE, EVERY SITE',
    title: 'This is the whole app',
    lead:
      'No dashboard, no account screen, no settings you have to understand. ' +
      'A home you name a site from, an identity that recomputes itself, and a ' +
      'browser that drops trackers before they load.',
    shots: [
      { src: 'identity', label: 'Identity', depth: 0.9 },
      { src: 'home', label: 'Home', depth: 1 },
      { src: 'browser', label: 'Browser', depth: 0.9 },
    ],
  },
  {
    id: 'phrase',
    navLabel: 'Phrase',
    kind: 'feature',
    god: 'Zeus',
    index: '01',
    relief: 'relief-phrase',
    eyebrow: 'ZEUS · THE ROOT',
    title: 'One phrase',
    lead:
      'Twelve words are the whole of it. Your wallet and every account Shadow ' +
      'makes for you are computed from them, so there is nothing on the phone ' +
      'to steal and nothing on a server to lose.',
    facts: [
      ['Derivation', 'BIP-39 → HKDF-SHA512, per registrable domain'],
      ['Stored on device', 'Nothing derived. Rotation counters only'],
      ['Recovery', 'The words rebuild all of it, on any device'],
    ],
  },
  {
    id: 'identity',
    navLabel: 'Identity',
    kind: 'feature',
    god: 'Athena',
    index: '02',
    relief: 'relief-masks',
    eyebrow: 'ATHENA · THE MANY',
    title: 'A different you on every site',
    lead:
      'Each site gets its own password and its own username, worked out from ' +
      'your phrase rather than kept anywhere. A site that loses its database ' +
      'loses a password that opens nothing else you own.',
    facts: [
      ['Per site', 'Password, username, address — all distinct'],
      ['Reuse', 'None. Two sites never see the same credential'],
      ['Phishing', 'Credentials derive from the loaded domain, so a lookalike gets a useless one'],
    ],
  },
  {
    id: 'mail',
    navLabel: 'Mail',
    kind: 'feature',
    god: 'Hermes',
    index: '03',
    relief: 'relief-slots',
    eyebrow: 'HERMES · THE MESSENGER',
    title: 'An address per site',
    lead:
      'Sign-ups get an address belonging to that site alone, twenty characters ' +
      'that certify themselves against your key. When one starts drawing spam ' +
      'you replace it, and only the site you gave it to is affected.',
    facts: [
      ['Local part', '20 chars, derived — the address proves its own key'],
      ['Burn', 'Replace one address without touching the others'],
      ['Rotation', 'Password and address rotate on separate counters'],
    ],
  },
  {
    id: 'trackers',
    navLabel: 'Trackers',
    kind: 'feature',
    god: 'Ares',
    index: '04',
    relief: 'relief-threshold',
    eyebrow: 'ARES · THE GUARD',
    title: 'Nothing follows you out',
    lead:
      'Known trackers are stopped at the request rather than hidden after the ' +
      'fact. Where the platform lets Shadow check, third-party cookies are ' +
      'blocked too — and Settings reports what your device actually does.',
    facts: [
      ['Blocking', 'At the request, before anything loads'],
      ['Measured', 'On a real device, not assumed'],
      ['Reported', 'Settings shows the true state, including "unknown"'],
    ],
  },
  {
    id: 'download',
    kind: 'download',
    god: null,
    relief: 'relief-arch',
    eyebrow: 'THE GATE',
    title: 'Walk through',
    // This said "put your name down and we will tell you the day it opens".
    // There is no form on this page and no server to receive one, so that was
    // a promise with no mechanism behind it — the exact thing the app's own
    // copy pass spent a day removing. Either build the capture or do not offer
    // it; until the first is true, say the second.
    lead:
      'Shadow is in build. Neither store listing exists yet, and there is ' +
      'nothing here to sign up to — when the builds go out they will be ' +
      'linked from this page.',
    platforms: [
      {
        id: 'ios',
        name: 'iOS',
        sub: 'iPhone · iPad',
        state: 'Coming soon',
        note: 'TestFlight first',
      },
      {
        id: 'android',
        name: 'Android',
        sub: 'Phone · Tablet',
        state: 'Coming soon',
        note: 'APK and Play',
      },
    ],
    note: 'Neither build is public yet. These buttons do nothing on purpose — we would rather they said so.',
  },
];

/**
 * The loop, laid out.
 *
 *   0 ─────────── ZOOM_SPAN ─────────── + N × STAGE_SPAN ─────────── LOOP
 *   │ the zoom     │ stage 0            │ …                          │
 *   phone on the   first thing                                    wraps to
 *   hero           through the opening                            the phone
 *
 * The last stage is the download and the wrap puts you back at the hero, so
 * walking the whole thing returns you to the door you came in by. That is the
 * conceit, and it is the reason the loop exists rather than decoration.
 */
export const LOOP_LENGTH = ZOOM_SPAN + STAGES.length * STAGE_SPAN;
export const stagePosition = (i) => ZOOM_SPAN + i * STAGE_SPAN;

/** Shown along the bottom, because a loop with no landmarks is disorienting. */
export const NAV = [
  { id: 'top', label: 'Top', at: 0 },
  ...STAGES.map((s, i) => ({
    id: s.id,
    label: s.kind === 'download' ? 'Get it' : s.navLabel || s.title,
    at: stagePosition(i),
  })),
];
