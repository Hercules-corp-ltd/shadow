#!/usr/bin/env node
// Builds assets/blocklist/trackers.json from EasyPrivacy.
//
// Run:  node tool/build_blocklist.mjs [path-to-easyprivacy.txt]
//
// This is a BUILD-TIME step, deliberately. The generated JSON is committed so
// that builds are reproducible and the exact rules shipped to users are
// reviewable in a diff, rather than being whatever a list server returned on
// the day someone ran a release.
//
// ## Why a curated list rather than all of EasyPrivacy
//
// EasyPrivacy carries ~47,000 plain domain rules. WKContentRuleList tops out
// around 150,000, so the full list would technically fit — but it costs
// roughly a hundred times the on-device compile time and, far more importantly, a
// hundred times the breakage surface, in exchange for a long tail of
// near-zero-prevalence domains. For scale: DuckDuckGo's entire iOS blocklist
// is ~3,700 rules and Firefox Focus ships ~2,600. Starting small and honest
// beats starting large and broken.
//
// ## Licence
//
// EasyPrivacy is CC BY-SA 3.0. The ShareAlike obligation attaches to this
// derived rule file, not to the app source — which is satisfied because this
// repository is public. Attribution to "The EasyList authors" ships in-app.
//
// Deliberately NOT sourced from DuckDuckGo Tracker Radar, DDG's
// tracker-blocklists, or Disconnect's services.json: all three are
// CC BY-NC-SA 4.0, and NonCommercial is a prohibition rather than a footnote
// for anything that might ever be monetised. Choosing that data now would
// mean rebuilding the list later.

import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

// Highest-prevalence ad-tech, analytics and data-broker domains. Ranking is
// research; the rule text itself comes from EasyPrivacy, and a domain is only
// emitted if EasyPrivacy actually carries a rule for it — so this file cannot
// invent a tracker that no filter list recognises.
// Note on scope: EasyPrivacy is a TRACKER list. Pure ad-serving and RTB
// exchanges (doubleclick.net, adnxs.com, pubmatic.com and friends) live in
// EasyList instead, so they are absent here by design. That means this
// feature blocks tracking, not advertising — the product copy has to say
// exactly that, and ad blocking would be a separate list and a separate
// decision.
const CURATED = [
  // Analytics
  'google-analytics.com', 'scorecardresearch.com', 'quantserve.com',
  'chartbeat.com', 'statcounter.com', 'imrworldwide.com', 'newrelic.com',
  'nr-data.net', 'mixpanel.com', 'amplitude.com', 'heap.io',
  'heapanalytics.com', 'kissmetrics.com', 'kissmetrics.io', 'parsely.com',
  'cxense.com', 'webtrends.com', 'coremetrics.com', 'sitestat.com',
  'hit.gemius.pl', 'gemius.pl', 'effectivemeasure.net', 'alexametrics.com',
  'histats.com', 'openstat.net', 'clicky.com', 'getclicky.com',

  // Session recording and heatmaps — these replay what a person did on a
  // page, keystroke by keystroke, which is the most invasive category here.
  'hotjar.com', 'fullstory.com', 'mouseflow.com', 'crazyegg.com',
  'inspectlet.com', 'luckyorange.com', 'smartlook.com', 'sessioncam.com',
  'clicktale.net', 'quantummetric.com', 'contentsquare.net',
  'decibelinsight.com', 'glassboxdigital.io', 'logrocket.com', 'clarity.ms',

  // Identity graphs, data brokers and cookie syncing
  'crwdcntrl.net', 'demdex.net', 'tapad.com', 'bluekai.com', 'agkn.com',
  'exelator.com', 'krxd.net', 'everesttech.net', 'omtrdc.net', 'adobedtm.com',
  '2o7.net', 'mathtag.com', 'bidswitch.net', 'semasio.net', 'zeotap.com',
  'drawbridge.com', 'adsymptotic.com', 'permutive.com', 'lytics.io',

  // Behavioural advertising with a heavy tracking component
  'criteo.com', 'criteo.net', 'media.net', 'taboola.com', 'outbrain.com',
  'revcontent.com', 'zemanta.com', 'sharethis.com', 'addthis.com',

  // Mobile attribution
  'branch.io', 'adjust.com', 'appsflyer.com', 'kochava.com', 'singular.net',
  'apsalar.com', 'tenjin.io',
];

// Never block these, even though several rank far higher by prevalence.
// Every one is load-bearing for ordinary sites, and DuckDuckGo marks them
// "ignore" for the same reason. A blocker that visibly breaks the web gets
// uninstalled long before anyone notices the privacy win. If these are ever
// wanted, they belong behind an explicit "Strict (may break sites)" mode with
// breakage telemetry behind it — not in a default list.
const NEVER_BLOCK = new Set([
  'googletagmanager.com', 'google.com', 'gstatic.com', 'fonts.googleapis.com',
  'ajax.googleapis.com', 'googleapis.com', 'cloudflare.com', 'jsdelivr.net',
  'facebook.com', 'facebook.net', 'linkedin.com', 'youtube.com', 'twitter.com',
  'cdnjs.cloudflare.com', 'unpkg.com', 'bootstrapcdn.com',
]);

const sourcePath = process.argv[2] ?? 'easyprivacy.txt';
const source = readFileSync(sourcePath, 'utf8');

// EasyPrivacy option -> WKContentRuleList resource-type. Options with no
// equivalent (csp, redirect, removeparam, badfilter, popup, and the element
// hiding syntax) are not representable and are handled by skipping the rule
// entirely rather than emitting something that silently does nothing.
const RESOURCE_TYPES = {
  script: 'script',
  image: 'image',
  stylesheet: 'style-sheet',
  font: 'font',
  media: 'media',
  xmlhttprequest: 'raw',
  ping: 'raw',
  websocket: 'raw',
  other: 'raw',
  subdocument: 'document',
  document: 'document',
};

// Only plain domain anchors, with their options preserved.
const available = new Map();
for (const raw of source.split('\n')) {
  const match = /^\|\|([a-z0-9.-]+)\^(?:\$([a-z0-9,~_-]+))?$/.exec(raw.trim());
  if (!match) continue;
  const [, domain, optionText] = match;
  const options = optionText ? optionText.split(',') : [];

  // A negated option means the rule is scoped in a way this converter does
  // not model; skip rather than guess.
  if (options.some((o) => o.startsWith('~'))) continue;

  const resourceTypes = [];
  let representable = true;
  for (const option of options) {
    if (option === 'third-party') continue;
    const mapped = RESOURCE_TYPES[option];
    if (!mapped) { representable = false; break; }
    if (!resourceTypes.includes(mapped)) resourceTypes.push(mapped);
  }
  if (!representable) continue;

  // Prefer the least scoped rule available for a domain: a bare ||d^ blocks
  // more than ||d^$script, and where EasyPrivacy carries both, the broad one
  // is the one its authors intended to apply generally.
  const existing = available.get(domain);
  if (!existing || resourceTypes.length < existing.length) {
    available.set(domain, resourceTypes);
  }
}

const version = /^! Version: (\d+)/m.exec(source)?.[1] ?? 'unknown';

const emitted = [];
const missing = [];
for (const domain of CURATED) {
  if (NEVER_BLOCK.has(domain)) {
    throw new Error(`${domain} is in both CURATED and NEVER_BLOCK`);
  }
  if (!/^[a-z0-9.-]+$/.test(domain)) {
    // WebKit rejects the whole list with JSONDomainNotLowerCaseASCII rather
    // than skipping the offending entry, so one bad domain means no blocking
    // at all. Punycode before adding anything non-ASCII.
    throw new Error(`${domain} is not lowercase ASCII`);
  }
  if (!available.has(domain)) {
    missing.push(domain);
    continue;
  }
  const resourceTypes = available.get(domain);
  const escaped = domain.replace(/\./g, '\\.');

  const trigger = {
    // Matches the domain and any subdomain, on either scheme, and requires a
    // delimiter after so that "criteo.com.evil.test" cannot match.
    'url-filter': `^[^:]+://+([^:/]+\\.)?${escaped}[:/]`,
    // Third-party only. A first-party request to one of these domains means
    // the user went there deliberately, and blocking it breaks the site the
    // person actually asked for.
    'load-type': ['third-party'],
  };
  // Preserve EasyPrivacy's own scoping. Widening a $script rule into a
  // blanket block would be stricter than the list's authors intended and is
  // how a blocker starts breaking pages.
  if (resourceTypes.length > 0) trigger['resource-type'] = resourceTypes;

  emitted.push({ trigger, action: { type: 'block' } });
}

emitted.sort((a, b) =>
  a.trigger['url-filter'].localeCompare(b.trigger['url-filter']));

const json = JSON.stringify(emitted, null, 2);
const hash = createHash('sha256').update(json).digest('hex').slice(0, 16);

writeFileSync('assets/blocklist/trackers.json', `${json}\n`);
writeFileSync(
  'assets/blocklist/trackers.meta.json',
  `${JSON.stringify({
    source: 'EasyPrivacy',
    sourceVersion: version,
    licence: 'CC BY-SA 3.0',
    attribution: 'The EasyList authors',
    ruleCount: emitted.length,
    contentHash: hash,
  }, null, 2)}\n`,
);

console.log(`rules emitted : ${emitted.length}`);
console.log(`easyprivacy   : version ${version}, ${available.size} domain rules available`);
console.log(`content hash  : ${hash}`);
if (missing.length) {
  // Loudly, because a silently dropped domain is a tracker that is not blocked
  // while the list still looks healthy.
  console.log(`\nNOT IN EASYPRIVACY (not emitted): ${missing.join(', ')}`);
}
