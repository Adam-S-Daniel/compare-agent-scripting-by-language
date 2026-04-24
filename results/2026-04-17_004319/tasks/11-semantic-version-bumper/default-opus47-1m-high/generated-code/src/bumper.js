// Semantic version bumper — pure functions plus thin file IO helpers.
//
// Conventional Commits primer:
//   <type>[optional scope][!]: <description>
//   <BLANK LINE>
//   [optional body]
//   [optional footer(s)]
// A "!" after the type/scope OR a "BREAKING CHANGE:" footer signals breaking.
// Feat → minor, fix → patch, breaking → major. Other types (chore, docs, …)
// don't trigger a release on their own.

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const HEADER_RE = /^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s+(?<desc>.+)$/;

function parseCommit(message) {
  if (message == null || message === '') {
    throw new Error('empty commit message');
  }
  const lines = String(message).split(/\r?\n/);
  const header = lines[0];
  const body = lines.slice(1).join('\n');
  const m = header.match(HEADER_RE);
  if (!m) {
    return { type: null, scope: null, breaking: false, description: header, raw: message };
  }
  const breakingFooter = /(^|\n)BREAKING[ -]CHANGE:/.test(body);
  return {
    type: m.groups.type.toLowerCase(),
    scope: m.groups.scope || null,
    breaking: Boolean(m.groups.bang) || breakingFooter,
    description: m.groups.desc.trim(),
    raw: message,
  };
}

function determineBump(commits) {
  let bump = null;
  for (const c of commits) {
    if (c.breaking) return 'major';
    if (c.type === 'feat') bump = 'minor';
    else if (c.type === 'fix' && bump !== 'minor') bump = 'patch';
  }
  return bump;
}

const SEMVER_RE = /^(\d+)\.(\d+)\.(\d+)$/;

function bumpVersion(version, kind) {
  const m = String(version).trim().match(SEMVER_RE);
  if (!m) throw new Error(`invalid semver: ${version}`);
  let [maj, min, pat] = [Number(m[1]), Number(m[2]), Number(m[3])];
  switch (kind) {
    case 'major': return `${maj + 1}.0.0`;
    case 'minor': return `${maj}.${min + 1}.0`;
    case 'patch': return `${maj}.${min}.${pat + 1}`;
    default: throw new Error(`invalid bump type: ${kind}`);
  }
}

function renderChangelog(version, date, commits) {
  const breaking = commits.filter(c => c.breaking);
  const feats = commits.filter(c => c.type === 'feat' && !c.breaking);
  const fixes = commits.filter(c => c.type === 'fix' && !c.breaking);

  const lines = [`## ${version} - ${date}`, ''];
  const section = (title, items) => {
    if (!items.length) return;
    lines.push(`### ${title}`);
    for (const c of items) {
      const scope = c.scope ? `**${c.scope}:** ` : '';
      lines.push(`- ${scope}${c.description}`);
    }
    lines.push('');
  };
  section('Breaking Changes', breaking);
  section('Features', feats);
  section('Bug Fixes', fixes);
  return lines.join('\n');
}

function readVersion(filePath) {
  let text;
  try {
    text = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    throw new Error(`could not read version file at ${filePath}: ${e.message}`);
  }
  if (path.basename(filePath) === 'package.json') {
    try {
      const v = JSON.parse(text).version;
      if (!v) throw new Error('no "version" field in package.json');
      return v;
    } catch (e) {
      throw new Error(`could not read version from ${filePath}: ${e.message}`);
    }
  }
  return text.trim();
}

function writeVersion(filePath, newVersion) {
  if (path.basename(filePath) === 'package.json') {
    const text = fs.readFileSync(filePath, 'utf8');
    const pkg = JSON.parse(text);
    pkg.version = newVersion;
    // Preserve trailing newline if original had one.
    const ending = text.endsWith('\n') ? '\n' : '';
    fs.writeFileSync(filePath, JSON.stringify(pkg, null, 2) + ending);
  } else {
    fs.writeFileSync(filePath, newVersion + '\n');
  }
}

module.exports = {
  parseCommit,
  determineBump,
  bumpVersion,
  renderChangelog,
  readVersion,
  writeVersion,
};
