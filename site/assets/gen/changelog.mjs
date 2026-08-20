/**
 * Build the log panel's data from real git history.
 *
 * The reference site has a changelog panel with 114 entries. Ours could have
 * been a hand-written list of nice-sounding milestones, which is the usual
 * thing and is worth nothing — the whole point of a build log is that it is
 * evidence. This reads the actual commits.
 *
 * Two decisions worth recording:
 *
 *  - The subject line is the entry. These commits are written as a headline
 *    plus a body explaining what was wrong, so the subject alone already reads
 *    as a changelog line and the body is far too long for a panel. The first
 *    paragraph of the body becomes the blurb, trimmed.
 *
 *  - Commits that only move bytes around — merges, formatting, "wip" — are
 *    dropped. Not to flatter the log, but because an entry a reader cannot act
 *    on is noise, and a log that is mostly noise stops being read.
 *
 * Run: node site/assets/gen/changelog.mjs
 */
import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../../..');
const out = resolve(here, '../../data/changelog.json');

const SEP = '';   // record separator — safe inside prose, unlike newlines
const FIELD = '';

const raw = execFileSync(
  'git',
  ['log', `--pretty=format:%h${FIELD}%ad${FIELD}%s${FIELD}%b${SEP}`, '--date=short'],
  { cwd: repo, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
);

const SKIP = /^(merge|wip|fixup|squash|format|lint|bump|chore\(deps\))/i;

const entries = [];
for (const record of raw.split(SEP)) {
  const line = record.trim();
  if (!line) continue;
  const [hash, date, subject, body = ''] = line.split(FIELD);
  if (!subject || SKIP.test(subject)) continue;

  // First paragraph of the body, collapsed.
  const para = body
    .split(/\n\s*\n/)
    .map((p) => p.replace(/\s+/g, ' ').trim())
    .find((p) => p.length > 40 && !/^(co-authored|signed-off)/i.test(p));

  entries.push({
    hash,
    date,
    title: subject.trim(),
    blurb: para ? (para.length > 260 ? `${para.slice(0, 257).trimEnd()}…` : para) : '',
  });
}

mkdirSync(dirname(out), { recursive: true });
writeFileSync(
  out,
  JSON.stringify(
    {
      generated: entries[0]?.date ?? null,
      count: entries.length,
      since: entries[entries.length - 1]?.date ?? null,
      entries,
    },
    null,
    1,
  ),
);

console.log(`${entries.length} entries, ${entries[entries.length - 1]?.date} → ${entries[0]?.date}`);
