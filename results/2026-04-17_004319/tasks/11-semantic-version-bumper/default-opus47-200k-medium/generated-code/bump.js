#!/usr/bin/env node
// Semantic version bumper driven by conventional commit messages.
//
// Contract:
//   feat        -> minor bump
//   fix         -> patch bump
//   !   or "BREAKING CHANGE:" footer -> major bump
//   anything else (chore/docs/refactor/...) -> no release
//
// All file I/O lives in `run()`; the helper functions are pure so the tests
// can exercise parsing/bumping/changelog logic without touching the disk.

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const CONVENTIONAL_RE = /^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s*(?<subject>.+)$/;

// `delimiter` lets callers split a log that contains multi-line commit
// bodies (e.g. `git log --pretty=format:%s%n%b` joined by a sentinel).
function parseCommits(log, delimiter = '\n') {
  if (!log || !log.trim()) return [];
  return log
    .split(delimiter)
    .map((raw) => raw.trim())
    .filter(Boolean)
    .map(parseOneCommit)
    .filter(Boolean);
}

function parseOneCommit(raw) {
  const lines = raw.split('\n');
  const header = lines[0];
  const body = lines.slice(1).join('\n');
  const match = header.match(CONVENTIONAL_RE);
  if (!match) {
    // Unrecognised header — still capture it so downstream can see it,
    // but it won't trigger a release.
    return { type: 'other', scope: null, subject: header, breaking: false };
  }
  const { type, scope = null, bang, subject } = match.groups;
  const breaking = Boolean(bang) || /BREAKING CHANGE:/i.test(body);
  return { type: type.toLowerCase(), scope, subject, breaking };
}

function determineBump(commits) {
  let bump = 'none';
  for (const c of commits) {
    if (c.breaking) return 'major';
    if (c.type === 'feat' && bump !== 'major') bump = 'minor';
    else if (c.type === 'fix' && bump === 'none') bump = 'patch';
  }
  return bump;
}

function bumpVersion(version, kind) {
  const m = /^(\d+)\.(\d+)\.(\d+)$/.exec(String(version).trim());
  if (!m) throw new Error(`Invalid semantic version: "${version}"`);
  let [maj, min, pat] = m.slice(1).map(Number);
  switch (kind) {
    case 'major': return `${maj + 1}.0.0`;
    case 'minor': return `${maj}.${min + 1}.0`;
    case 'patch': return `${maj}.${min}.${pat + 1}`;
    case 'none':  return `${maj}.${min}.${pat}`;
    default: throw new Error(`Unknown bump kind: "${kind}"`);
  }
}

function generateChangelog(version, commits) {
  const breaking = commits.filter((c) => c.breaking);
  const feats = commits.filter((c) => c.type === 'feat' && !c.breaking);
  const fixes = commits.filter((c) => c.type === 'fix' && !c.breaking);
  const today = new Date().toISOString().slice(0, 10);
  const out = [`## ${version} - ${today}`, ''];
  if (breaking.length) {
    out.push('### BREAKING CHANGES', '');
    for (const c of breaking) out.push(`- ${c.subject}`);
    out.push('');
  }
  if (feats.length) {
    out.push('### Features', '');
    for (const c of feats) out.push(`- ${c.subject}`);
    out.push('');
  }
  if (fixes.length) {
    out.push('### Bug Fixes', '');
    for (const c of fixes) out.push(`- ${c.subject}`);
    out.push('');
  }
  return out.join('\n');
}

function readVersion(file) {
  const raw = fs.readFileSync(file, 'utf8');
  if (file.endsWith('.json')) {
    const pkg = JSON.parse(raw);
    if (!pkg.version) throw new Error(`No "version" field in ${file}`);
    return { version: pkg.version, kind: 'json', data: pkg };
  }
  return { version: raw.trim(), kind: 'plain', data: null };
}

function writeVersion(file, state, newVersion) {
  if (state.kind === 'json') {
    state.data.version = newVersion;
    fs.writeFileSync(file, JSON.stringify(state.data, null, 2) + '\n');
  } else {
    fs.writeFileSync(file, newVersion + '\n');
  }
}

function run({ versionFile, commitsFile, changelogFile, delimiter = '---COMMIT---' }) {
  if (!fs.existsSync(commitsFile)) {
    throw new Error(`Commits file not found: ${commitsFile}`);
  }
  if (!fs.existsSync(versionFile)) {
    throw new Error(`Version file not found: ${versionFile}`);
  }
  const log = fs.readFileSync(commitsFile, 'utf8');
  // Auto-detect: if the delimiter is absent, fall back to one-line-per-commit.
  const effectiveDelim = log.includes(delimiter) ? delimiter : '\n';
  const commits = parseCommits(log, effectiveDelim);
  const kind = determineBump(commits);
  const state = readVersion(versionFile);
  const newVersion = bumpVersion(state.version, kind);

  if (kind !== 'none') {
    writeVersion(versionFile, state, newVersion);
    const entry = generateChangelog(newVersion, commits);
    const prior = fs.existsSync(changelogFile) ? fs.readFileSync(changelogFile, 'utf8') : '';
    fs.writeFileSync(changelogFile, entry + '\n' + prior);
  }

  return { newVersion, oldVersion: state.version, kind, commits };
}

module.exports = {
  parseCommits,
  determineBump,
  bumpVersion,
  generateChangelog,
  run,
};

// CLI entrypoint
if (require.main === module) {
  const args = process.argv.slice(2);
  const opts = { versionFile: 'package.json', commitsFile: 'commits.txt', changelogFile: 'CHANGELOG.md' };
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const val = args[i + 1];
    if (key === '--version-file') opts.versionFile = val;
    else if (key === '--commits') opts.commitsFile = val;
    else if (key === '--changelog') opts.changelogFile = val;
    else {
      console.error(`Unknown option: ${key}`);
      process.exit(2);
    }
  }
  try {
    const result = run(opts);
    console.log(`OLD_VERSION=${result.oldVersion}`);
    console.log(`BUMP=${result.kind}`);
    console.log(`NEW_VERSION=${result.newVersion}`);
  } catch (err) {
    console.error(`ERROR: ${err.message}`);
    process.exit(1);
  }
}
