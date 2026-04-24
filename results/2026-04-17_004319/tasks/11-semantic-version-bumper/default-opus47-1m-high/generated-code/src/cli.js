#!/usr/bin/env node
// CLI entry point. Reads commits from a file, computes the next version,
// updates the version file in place, prepends a changelog entry, and prints
// the new version to stdout. Exits non-zero with a useful stderr message
// on missing inputs or invalid arguments.

'use strict';

const fs = require('node:fs');
const path = require('node:path');
const {
  parseCommit,
  determineBump,
  bumpVersion,
  renderChangelog,
  readVersion,
  writeVersion,
} = require('./bumper');

function parseArgs(argv) {
  const opts = {
    versionFile: 'package.json',
    commitsFile: null,
    changelogFile: null,
    date: new Date().toISOString().slice(0, 10),
    dryRun: false,
  };
  const aliases = {
    '--version-file': 'versionFile',
    '--commits-file': 'commitsFile',
    '--changelog': 'changelogFile',
    '--date': 'date',
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') { opts.dryRun = true; continue; }
    if (a === '-h' || a === '--help') { opts.help = true; continue; }
    if (aliases[a]) {
      const val = argv[++i];
      if (val == null) throw new Error(`missing value for ${a}`);
      opts[aliases[a]] = val;
    } else {
      throw new Error(`unknown argument: ${a}`);
    }
  }
  return opts;
}

function help() {
  return [
    'Usage: bumper [options]',
    '',
    'Options:',
    '  --version-file PATH   package.json or VERSION (default: package.json)',
    '  --commits-file PATH   file with one conventional commit per line/block',
    '  --changelog PATH      changelog file to prepend (optional)',
    '  --date YYYY-MM-DD     date to use in changelog (default: today)',
    '  --dry-run             do not modify any files; just print the new version',
    '  -h, --help            show this help',
  ].join('\n');
}

// Commit logs may have multi-line bodies. Blocks separated by a line of
// "---" act as a portable, language-neutral delimiter. If no delimiter is
// present, treat each non-empty line as one commit.
function splitCommits(text) {
  if (text.includes('\n---\n') || text.startsWith('---\n') || text.endsWith('\n---')) {
    return text.split(/\n---\n/).map(s => s.trim()).filter(Boolean);
  }
  return text.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
}

function main(argv) {
  let opts;
  try { opts = parseArgs(argv); }
  catch (e) { process.stderr.write(`error: ${e.message}\n${help()}\n`); return 2; }
  if (opts.help) { process.stdout.write(help() + '\n'); return 0; }

  let current;
  try { current = readVersion(opts.versionFile); }
  catch (e) { process.stderr.write(`error: ${e.message}\n`); return 1; }

  let commitsText = '';
  if (opts.commitsFile) {
    try { commitsText = fs.readFileSync(opts.commitsFile, 'utf8'); }
    catch (e) { process.stderr.write(`error: could not read commits file ${opts.commitsFile}: ${e.message}\n`); return 1; }
  }

  const commits = splitCommits(commitsText).map(parseCommit);
  const bump = determineBump(commits);
  if (bump === null) {
    process.stdout.write(`no release: no feat/fix/breaking commits since ${current}\n`);
    process.stdout.write(`version=${current}\n`);
    return 0;
  }

  const next = bumpVersion(current, bump);
  process.stdout.write(`bump=${bump}\n`);
  process.stdout.write(`previous=${current}\n`);
  process.stdout.write(`version=${next}\n`);

  if (opts.dryRun) return 0;

  try { writeVersion(opts.versionFile, next); }
  catch (e) { process.stderr.write(`error: could not write version file: ${e.message}\n`); return 1; }

  if (opts.changelogFile) {
    const entry = renderChangelog(next, opts.date, commits);
    let existing = '';
    if (fs.existsSync(opts.changelogFile)) existing = fs.readFileSync(opts.changelogFile, 'utf8');
    const prefix = existing.startsWith('# Changelog')
      ? existing.replace(/^# Changelog\n+/, '# Changelog\n\n')
      : '# Changelog\n\n' + existing;
    // Insert new entry directly after the header.
    const header = '# Changelog\n\n';
    const rest = prefix.startsWith(header) ? prefix.slice(header.length) : prefix;
    fs.writeFileSync(opts.changelogFile, header + entry + '\n' + rest);
  }
  return 0;
}

if (require.main === module) {
  process.exit(main(process.argv.slice(2)));
}

module.exports = { main, parseArgs, splitCommits };
