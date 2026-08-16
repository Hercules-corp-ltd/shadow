#!/usr/bin/env node
// Builds lib/identity/public_suffix_data.dart from the Public Suffix List.
//
// Run:  node tool/build_psl.mjs [path-to-public_suffix_list.dat]
// Fetch: curl -o psl.dat https://publicsuffix.org/list/public_suffix_list.dat
//
// This is a BUILD-TIME step and the output is committed, for the same reason
// the tracker blocklist is: builds stay reproducible, and the exact rules
// shipped to users are reviewable in a diff rather than being whatever a
// list server returned on release day.
//
// ## Why generated Dart source rather than a bundled asset
//
// RegistrableDomain.of() is synchronous and sits inside the derivation path,
// which is deliberately pure Dart with no platform channels — the identity
// core runs identically in a unit test with no Flutter binding. Loading an
// asset needs rootBundle, which needs that binding, so an asset would drag
// the whole identity core onto the Flutter engine to answer a question about
// a string. Generated source keeps it a pure function.
//
// The cost is that updating the list needs an app release. That is the right
// trade today; an over-the-air override belongs in the per-site adapter
// bundle, where it can be signed and versioned, not bolted onto this.
//
// ## Licence
//
// The Public Suffix List is MPL 2.0. The obligation attaches to the list and
// to this derived file, both of which are public in this repository, and
// attribution ships in the generated header.

import { readFileSync, writeFileSync } from 'node:fs';

const source = process.argv[2] ?? 'psl.dat';
const raw = readFileSync(source, 'utf8');

const version =
  raw.match(/^\/\/ VERSION:\s*(.+)$/m)?.[1]?.trim() ?? 'unknown';

const rules = [];
const wildcards = [];
const exceptions = [];

for (const line of raw.split('\n')) {
  const rule = line.trim();
  if (rule === '' || rule.startsWith('//')) continue;

  if (rule.startsWith('!')) {
    // An exception un-registers one specific host from a wildcard above it.
    exceptions.push(rule.slice(1));
  } else if (rule.startsWith('*.')) {
    // Store the PARENT. `*.ck` means "any single label under ck is itself a
    // public suffix", so the lookup asks whether a candidate's parent is a
    // wildcard, not whether the candidate is.
    wildcards.push(rule.slice(2));
  } else {
    rules.push(rule);
  }
}

// Multi-tenant hosts the PSL does not carry.
//
// The PSL's private section is OPT-IN: an operator has to submit their own
// domain. Plenty never did, and the consequence for Shadow is specific and
// bad — every tenant under an unlisted host collapses to one registrable
// domain, so they share one derived identity, and once addresses are real
// mailboxes they share a mailbox. Whoever runs tenant A can then trigger a
// password reset for the user's account at tenant B and read the code.
//
// So this list exists, it is a liability, and it must be justified entry by
// entry. Only add a host where different, mutually untrusted parties get
// subdomains. Do not add a CDN, and do not add a company's own subdomains.
const supplement = [
  'wordpress.com',   // millions of independently-owned blogs
  'substack.com',    // one publication per subdomain, unrelated owners
  'tumblr.com',
  'blogspot.co.uk',  // country blogspot variants beyond those the PSL lists
  'weebly.com',
  'squarespace.com',
  'webflow.io',
  'carrd.co',
  'gumroad.com',
  'itch.io',
  'bandcamp.com',
  'medium.com',      // custom publication subdomains
  'zendesk.com',     // per-customer helpdesks, and they send real mail
  'freshdesk.com',
  'atlassian.net',   // per-tenant Jira/Confluence
  'myshopify.io',
  'shopifypreview.com',
  'discourse.group',
  'statuspage.io',
];

const supplementNew = supplement.filter((d) => !rules.includes(d));
for (const d of supplementNew) rules.push(d);

rules.sort();
wildcards.sort();
exceptions.sort();

const header = `// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Built by tool/build_psl.mjs from the Public Suffix List.
// PSL version: ${version}
//
// The Public Suffix List is available at https://publicsuffix.org/list/ and
// is licensed under the Mozilla Public License, v. 2.0
// (https://mozilla.org/MPL/2.0/).
//
// ${rules.length} suffix rules (${supplementNew.length} added by the
// supplement in the build tool, for multi-tenant hosts the PSL omits),
// ${wildcards.length} wildcard rules, ${exceptions.length} exceptions.
`;

function block(name, values) {
  return `\n/// One rule per line. See ${name === 'kWildcardParents' ? 'the wildcard note in RegistrableDomain' : 'publicsuffix.org/list'}.\nconst String ${name} = '''\n${values.join('\n')}\n''';\n`;
}

const out =
  header +
  block('kPublicSuffixRules', rules) +
  block('kWildcardParents', wildcards) +
  block('kSuffixExceptions', exceptions);

writeFileSync('lib/identity/public_suffix_data.dart', out);

console.log(
  `wrote lib/identity/public_suffix_data.dart — ` +
    `${rules.length} rules (+${supplementNew.length} supplement), ` +
    `${wildcards.length} wildcards, ${exceptions.length} exceptions, ` +
    `PSL ${version}`,
);
